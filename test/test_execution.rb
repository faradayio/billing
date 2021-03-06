require 'helper'

class TestExecution < Test::Unit::TestCase
  if ENV['TEST_KEY']
    def test_001_cm1_execution
      ::BrighterPlanet.billing.cm1.bill do |query|
        @execution_id = query.execution_id
        query.emitter = 'Flight'
        query.timeframe = Timeframe.this_year
        query.key = '091239012830192'
        query.url = 'http://query.url'
        query.methodology = 'http://methodology.url'
        query.compliance = 'good_protocol'
        query.cm1_version = '1092019309120931923'
        query.emitter_version = '1209120931023912903'
        query.certified = true
        query.color = 'red'
        query.remote_ip = 'remote.ip.ip.ip'
        query.referer = 'http://referer'
        query.callback = 'http://callback'
        query.guid = '0192309jsjoijoijdoijo'
        query.input = {
          :foo => { :bar => 'foo' },
          :bar => { :nar => 'dar' }
        }
        # the nubbies
        #@impact = emitter_instance.impact timeframe, :comply => compliance
        query.impact = { 'carbon' => 14.34 }
      end
    end
  end
end
