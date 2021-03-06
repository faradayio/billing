# http://stackoverflow.com/questions/5723889/how-can-i-stringify-a-bson-object-inside-of-a-mongodb-map-function
# http://stackoverflow.com/questions/5724086/why-is-mongodb-treating-these-two-keys-as-they-same
# Billing::AuthoritativeStore.instance.distinct(service.name, field, selector)
require 'bson'

module BrighterPlanet
  class Billing
    class Billable
      class Top
        include ::Enumerable
        include EachHash
        include ToCSV
        include TimeAttrs

        EXCLUDED_FIELDS = [ :started_at, :stopped_at ]

        class << self
          #{'input.airline':'AA','input.date':'2009-04-30','input.timeframe':'2009-01-01/2010-01-01','emitter':'Flight','input.origin_airport':'STL','input.destination_airport':'LAX','key':'sdaiosjaoisdjaoisdjaojsd','input.segments_per_trip':'1','input.trips':'1','input.aircraft':'M83'}
          def flatten(selector)
            selector = selector.symbolize_keys.except(*EXCLUDED_FIELDS)
            selector.inject({}) do |memo, (k, v)|
              if v.is_a?(::Hash)
                v.each do |k1, v1|
                  if v1.is_a?(::Hash) # maybe i could rewrite this to be recursive... as it is, 2 levels seems enough
                    v1.each do |k11, v11|
                      memo["#{k}.#{k1}.#{k11}"] = v11
                    end
                  else
                    memo["#{k}.#{k1}"] = v1
                  end
                end
              else
                memo[k] = v
              end
              memo
            end
          end

          # db.customers.find( { name : { $regex : 'acme.*corp', $options: 'i' } } );
          def regexpify(selector)
            selector = selector.symbolize_keys.except(*EXCLUDED_FIELDS)
            selector.inject({}) do |memo, (k, v)|
              memo[k] = if v.is_a?(::String) and v =~ /\A\s+/
                { '$regex' => ('^\\s+' + v.lstrip) }
              else
                v
              end
              memo
            end
          end
        end
        
        attr_reader :parent
        attr_reader :limit

        # attrs:
        # * limit
        # * field
        # * selector
        def initialize(parent, attrs = {})
          @parent = parent
          attrs.each do |k, v|
            instance_variable_set("@#{k}", v) unless v.nil?
          end
        end
        
        def field
          @field.to_sym
        end

        def each
          cache! if cache.empty?
          cache.each do |doc|
            yield doc
          end
        end
        
        def columns
          [ :"selector_for_top_values_of_#{field}" ]
        end

        def selector
          @selector.symbolize_keys.reverse_merge field => { :'$exists' => true }#, :'$nin' => [ '', nil, {} ]}
        end

        alias_method_chain :selector, :time_attrs

        def map_function
          ::BSON::Code.new <<-EOS
            function() {
              emit(this.#{field}, 1);
            }
          EOS
        end

        def reduce_function
          ::BSON::Code.new <<-EOS
            function(k, vals) {
              var sum=0;
              for (var i in vals) sum += vals[i];
              return sum;
            }
          EOS
        end

        def write_csv(f)
          f.puts columns.to_csv
          each do |top_value|
            output = Top.regexpify Top.flatten(selector.merge(field => top_value))
            f.puts [ output.to_json ].to_csv
          end
        end
        
        private
        
        def cache
          @cache ||= []
        end
                
        def cache!
          output_collection = parent.map_reduce(map_function, reduce_function, :query => selector)
          output_collection.find({}, :limit => limit, :sort => [['value', ::Mongo::DESCENDING]]).each do |doc|
            cache.push doc['_id']
          end
          output_collection.drop
        end
      end
    end
  end
end
