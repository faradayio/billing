require 'helper'

class TestBrighterPlanetBilling < Test::Unit::TestCase
  def test_store_to_sdb
    params = { 'make' => 'Nissan', 'key' => 'test_store_to_sdb', 'url' => 'http://carbon.brighterplanet.com/automobiles.json?make=Nissan' }
    answer = { 'emission' => '49291' }
    execution_id = nil
    ::BrighterPlanet::Billing.emission_estimate_service.queries.start do |query|
      query.key = params['key']
      query.input_params = params
      query.url = params['url']
      query.emitter_common_name = 'automobile'
      if params['key'] and params['url']
        query.remote_ip = params['remote_ip']
        query.referer = params['referer']
      end
      query.execute do
        # rubber stamp
      end
      query.output_params = answer
      execution_id = query.execution_id
    end
    sleep 1
    stored_query = ::BrighterPlanet::Billing.emission_estimate_service.queries.by_execution_id execution_id
    assert_equal 'emission_estimate_service', stored_query.service
    assert_equal answer['emission'], stored_query.output_params['emission']
  end
  
  def test_catches_errors_with_hoptoad
    ::ENV['BRIGHTER_PLANET_BILLING_DISABLE_HOPTOAD'] = 'false'
    assert_raises(::BrighterPlanet::Billing::ReportedExceptionToHoptoad) do
      ::BrighterPlanet::Billing.emission_estimate_service.queries.start do |query|
        query.execute { raise StandardError }
      end
    end
  end
  
  def test_catches_errors_without_hoptoad
    ::ENV['BRIGHTER_PLANET_BILLING_DISABLE_HOPTOAD'] = 'true'
    assert_raises(StandardError) do
      ::BrighterPlanet::Billing.emission_estimate_service.queries.start do |query|
        query.execute { raise StandardError }
      end
    end
  end
  
  # def test_lookup
  #   assert ::BrighterPlanet::Billing.emission_estimate_service.queries.by_key('test_store_to_sdb').any?
  # end
end
