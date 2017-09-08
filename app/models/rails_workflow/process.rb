# frozen_string_literal: true

module RailsWorkflow
  class Process < ActiveRecord::Base
    include Status
    include Processes::DependencyResolver

    belongs_to :template, class_name: 'RailsWorkflow::ProcessTemplate'
    has_many :operations, class_name: 'RailsWorkflow::Operation'
    has_one :parent_operation,
            class_name: 'RailsWorkflow::Operation',
            foreign_key: :child_process_id

    alias parent parent_operation
    has_one :context, class_name: 'RailsWorkflow::Context', as: :parent
    has_many :workflow_errors, class_name: 'RailsWorkflow::Error', as: :parent

    delegate :data, to: :context
    scope :by_status, ->(status) { where(status: status) }

    def manager
      @manager ||= template.manager_class.new(self)
    end

    def self.count_by_statuses
      query = RailsWorkflow.config.sql_dialect::COUNT_STATUSES

      statuses = connection.select_all(query).rows

      statuses_array.map do |status|
        statuses.detect { |s| s.first.to_i == status }.try(:last).to_i
      end
    end

    def self.statuses_array
      (NOT_STARTED..ROLLBACK).to_a
    end

    # TODO: do we need to raise some errors if all operations
    # are completed but process status is incomplete?
    def incomplete?
      incomplete_statuses.include?(status) &&
        incompleted_operations.size.zero?
    end

    # Returns set or operation that not yet completed.
    # Operation complete in DONE, SKIPPED, CANCELED, etc many other statuses
    def incompleted_operations
      operations.reject(&:completed?)
    end

    def can_start?
      status == Status::NOT_STARTED && !operations.empty?
    end

    def complete
      self.status = Status::DONE
      save
    end
  end
end
