require 'active_record'

module BrighterPlanet
  module Billing
    class Cache
      include ::Singleton
      def synchronized?
        Billable.untried.count.zero?
      end
      def put(execution_id, hsh)
        billable = Billable.find_or_create_by_execution_id execution_id
        billable.update_attributes! :content => hsh
      end
      def synchronize
        until synchronized?
          billable = Billable.untried.first
          begin
            Billing.authoritative_database.put billable.execution_id, billable.content
            billable.destroy
          rescue ::Exception => exception
            $stderr.puts exception.inspect
            billable.update_attributes! :failed => true
          end
        end
      end
      class Billable < ::ActiveRecord::Base
        set_table_name 'brighter_planet_billing_billables'
        serialize :content
        class << self
          def create_table
            unless connection.table_exists?(table_name)
              connection.create_table table_name do |t|
                t.string :execution_id
                t.text :content
                t.boolean :failed, :default => false
                t.timestamps
              end
              reset_column_information
            end
          end
        end
        if ::ActiveRecord::VERSION::MAJOR == 3
          def self.untried
            where arel_table[:failed].not_eq(true)
          end
        else
          named_scope :untried, :conditions => { :failed => false }
        end
      end
    end
  end
end
        