module Hourglass
  class TimeTracker < ApplicationRecord
    include Namespace
    include ProjectIssueSyncing

    belongs_to :user
    belongs_to :project
    belongs_to :issue
    belongs_to :activity, class_name: 'TimeEntryActivity', foreign_key: 'activity_id'
    has_one :fixed_version, through: :issue

    acts_as_customizable

    after_initialize :init
    before_validation if: :project_id_changed? do
      self.activity ||= TimeEntryActivity.respond_to?(:default_activity_id) ?
                          TimeEntryActivity.find_by(id: TimeEntryActivity.default_activity_id(user, project)) :
                          user.default_activity(TimeEntryActivity.applicable(user.projects.find_by id: project_id)) if project.present?
    end
    before_update if: :project_id_changed? do
      update_round project
      true
    end

    validates_uniqueness_of :user_id
    validates_presence_of :user, :start
    validates_presence_of :project, if: Proc.new { |tt| tt.project_id.present? }
    validates_presence_of :issue, if: Proc.new { |tt| tt.issue_id.present? }
    validates_presence_of :activity, if: Proc.new { |tt| tt.activity_id.present? }
    validates_length_of :comments, maximum: 255, allow_blank: true
    validate :does_not_overlap_with_other, if: [:user, :start?], on: :update

    class << self
      alias_method :start, :create
    end

    def stop
      stop = DateTimeCalculations.calculate_stoppable_time start, project: project
      time_log = nil
      transaction(requires_new: true) do
        if start < stop
          time_log = TimeLog.create time_log_params.merge stop: stop
          raise ActiveRecord::Rollback unless time_log.persisted?
          time_booking = bookable? ? time_log.book(time_booking_params) : nil
          raise ActiveRecord::Rollback if time_booking && !time_booking.persisted?
        end
        destroy
      end
      time_log
    end

    def hours
      DateTimeCalculations.time_diff_in_hours start, Time.now.change(sec: 0) + 1.minute
    end

    def available_custom_fields
      CustomField.where("type = 'TimeEntryCustomField'").sorted.to_a
    end

    def validate_custom_field_values
      super unless new_record?
    end

    def clamp?
      DateTimeCalculations.clamp? start, project: project
    end

    def activity_options
      project.present? ? TimeEntryActivity.applicable(user.projects.find_by id: project_id) : TimeEntryActivity.where(id: 0)
    end

    def default_activity_id
      @default_activity_id ||= TimeEntryActivity.respond_to?(:default_activity_id) ?
                                 TimeEntryActivity.default_activity_id(user, project) :
                                 user.default_activity(activity_options)&.id if project.present?
    end

    def as_json(options = nil)
      form_details = options&.delete(:form_details)
      super.tap do |tmp|
        tmp.merge!({
                     issue_label: issue.present? ? "##{issue.id} #{issue.subject}" : nil,
                     activities: activity_options.map { |activity|
                       { id: activity.id, name: activity.name, isDefault: default_activity_id == activity.id }
                     }
                   }.as_json) if form_details
        tmp
      end
    end

    private

    def init
      now = Time.now.change sec: 0
      self.user ||= User.current
      self.project ||= issue&.project
      update_round project unless round.present?
      self.start ||= user.hourglass_time_logs.find_by(stop: now + 1.minute)&.stop || now
    end

    def time_log_params
      attributes.with_indifferent_access.slice :start, :user_id, :comments
    end

    def time_booking_params
      attributes.with_indifferent_access.slice(:project_id, :issue_id, :activity_id, :round)
                .merge custom_field_values: custom_field_values.inject({}) { |h, v| h[v.custom_field_id.to_s] = v.value; h }
    end

    def bookable?
      project.present?
    end

    def update_round(project = nil)
      self.round = !Hourglass::SettingsStorage[:round_sums_only, project: project] &&
        Hourglass::SettingsStorage[:round_default, project: project]
    end

    def does_not_overlap_with_other
      errors.add :base, :overlaps if user.hourglass_time_logs.overlaps_with(start, Time.now).any?
    end
  end
end
