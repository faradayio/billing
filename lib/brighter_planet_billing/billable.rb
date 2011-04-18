require 'benchmark'

module BrighterPlanet
  class Billing
    class Billable
      class << self
        def service
          raise ::RuntimeError, "[brighter_planet_billing] subclass of Billable must define .service"
        end
        
        # Find that acts like mongo
        def find(selector, opts = {})
          ary = []
          stream(selector, opts) { |billable| ary.push billable }
          ary
        end
      
        def find_one(selector, opts = {})
          if doc = Billing.storage.find_one(service.name, selector, opts)
            new doc
          end
        end
      
        # If you pass no args, it counts all docs
        # Otherwise you can pass selector and opts like find
        def count(*args)
          selector = args[0] || {}
          opts = args[1] || {}
          Billing.storage.count service.name, selector, opts
        end

        # Sort of like #each with finder args (selector and opts)
        def stream(selector, opts = {})
          Billing.storage.find(service.name, selector, opts).each do |doc|
            yield new(doc)
          end
        end

        def sample(selector, opts = {})
          Sample.new self, selector, opts
        end
        
        def bill(&blk)
          billable = new
          billable.bill &blk
          billable.save
          billable
        end
      end

      attr_accessor :params
      attr_accessor :year
      attr_accessor :month
      attr_accessor :key
      attr_accessor :remote_ip
      attr_accessor :referer
      attr_accessor :execution_id
      attr_accessor :started_at
      attr_accessor :stopped_at
      attr_accessor :hoptoad_response
      attr_accessor :succeeded
      attr_accessor :realtime

      def initialize(doc = {})
        doc.each do |k, v|
          if respond_to? "#{k}="
            send "#{k}=", v
          else
            instance_variable_set "@#{k}", v
          end
        end
      end

      def service
        self.class.service
      end

      def mongo_id
        @_id
      end

      def save
        Billing.storage.save_execution service.name, execution_id, to_hash
      end
      
      # piggyback off activerecord's json, which defines #as_json for everything
      def to_hash
        as_json.inject({}) do |memo, (k, v)|
          memo[k.to_sym] = (v.is_a?(::Symbol) ? v.to_s : v) unless v.nil?
          memo
        end
      end

      def bill(&blk)
        self.execution_id = Billing.generate_execution_id
        now = ::Time.now
        self.year = now.year
        self.month = now.month
        self.started_at = now
        self.hoptoad_response = nil
        self.succeeded = false
        self.realtime = ::Benchmark.realtime { blk.call self } # where the magic happens
        self.succeeded = true
      rescue ::Exception => exception
        if Billing.config.disable_hoptoad or Billing.config.allowed_exceptions.any? { |exception_class| exception.is_a? exception_class }
          raise exception
        else
          if respond_to?(:gather_hoptoad_debugging_data) and hoptoad_container = ::HoptoadNotifier.notify_or_ignore(exception, gather_hoptoad_debugging_data)
            self.hoptoad_response = hoptoad_container.body
          end
          raise Billing::ReportedExceptionToHoptoad
        end
      ensure
        self.stopped_at = ::Time.now
        save
      end
    end
  end
end