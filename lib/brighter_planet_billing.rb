require 'singleton'
require 'stringio'
require 'active_support'
require 'active_support/version'
if ::ActiveSupport::VERSION::MAJOR == 3
  require 'active_support/core_ext/module/delegation'
  require 'active_support/core_ext/object'
  require 'active_support/core_ext/hash'
  require 'active_support/core_ext/string/inflections'
  require 'active_support/json'
  require 'active_support/secure_random'
end
require 'hoptoad_notifier'

module BrighterPlanet
  def self.billing
    Billing.instance
  end
  
  class Billing
    autoload :Config, 'brighter_planet_billing/config'
    autoload :Storage, 'brighter_planet_billing/storage'
    autoload :Cache, 'brighter_planet_billing/cache'
    autoload :AuthoritativeStore, 'brighter_planet_billing/authoritative_store'
    autoload :Key, 'brighter_planet_billing/key'
    autoload :Billable, 'brighter_planet_billing/billable'
    autoload :Synchronization, 'brighter_planet_billing/synchronization'
    autoload :ToCSV, 'brighter_planet_billing/to_csv'
    
    # services
    autoload :EmissionEstimateService, 'brighter_planet_billing/emission_estimate_service'
    autoload :ReferenceDataService, 'brighter_planet_billing/reference_data_service'
    
    include ::Singleton
    
    class ReportedExceptionToHoptoad < RuntimeError; end
    
    def services
      [
        emission_estimate_service,
        reference_data_service
      ]
    end
    
    def keys
      Key
    end
    
    def emission_estimate_service
      EmissionEstimateService.instance
    end
    
    def reference_data_service
      ReferenceDataService.instance
    end
    
    def config
      Config.instance
    end
    
    def storage
      Storage.instance
    end
    
    def cache
      Cache.instance
    end
    
    def authoritative_store
      AuthoritativeStore.instance
    end
    
    def setup
      Cache::Document.create_table
      ::HoptoadNotifier.configure do |hoptoad_config|
        unless hoptoad_config.ignore.include? ::BrighterPlanet::Billing::ReportedExceptionToHoptoad
          hoptoad_config.ignore.push ::BrighterPlanet::Billing::ReportedExceptionToHoptoad
        end
      end
    end
    
    def synchronized?
      storage.synchronized?
    end
    
    def synchronize
      storage.synchronize
    end
  end
end
