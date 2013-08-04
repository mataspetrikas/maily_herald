module MailyHerald
  class Sequence < ActiveRecord::Base
    attr_accessible :name, :context_name, :conditions, :start, :start_var, :period

    has_many    :subscriptions,       :class_name => "MailyHerald::SequenceSubscription"
    has_many    :mailings,            :class_name => "MailyHerald::SequenceMailing", :order => "position ASC"

    validates   :context_name,        :presence => true
    validates   :name,                :presence => true

    def context
      @context ||= MailyHerald.context context_name
    end

    def subscription_for entity
      sequence_subscription = self.subscriptions.for_entity(entity).first
      unless sequence_subscription 
        if self.autosubscribe && context.scope.include?(entity)
          sequence_subscription = self.subscriptions.build
          sequence_subscription.entity = entity
          sequence_subscription.save
        else
          sequence_subscription = self.subscriptions.build
          sequence_subscription.entity = entity
        end
      end
      sequence_subscription
    end

    def destination_for entity
      context.destination.call(entity)
    end

    def mailing name
      if SequenceMailing.table_exists?
        mailing = SequenceMailing.find_or_initialize_by_name(name)
        mailing.sequence = self
        if block_given?
          yield(mailing)
        end
        mailing.save
        mailing
      end
    end

    def run
      current_time = Time.now
      self.context.scope.each do |entity|
        subscription = subscription_for entity
        next unless subscription.active?

        mailing = subscription.next_mailing

        if mailing && subscription.delivery_time_for(mailing) <= current_time
          mailing.deliver_to entity
        end
      end
    end
  end
end