require 'helper'

class TestBrighterPlanetBilling < Test::Unit::TestCase  
  def test_001_count
    assert(::BrighterPlanet.billing.emission_estimate_service.queries.count > 1_000)
  end
  
  def test_002_all_keys
    assert(BrighterPlanet.billing.keys.all.length > 0)
  end
  
  def test_011_immediate_store_to_mongo
    ::BrighterPlanet.billing.config.disable_caching = true
    params = { 'make' => 'Nissan', 'key' => 'test_store_to_mongo', 'url' => 'http://carbon.brighterplanet.com/automobiles.json?make=Nissan' }
    emission = 49213
    execution_id = nil
    ::BrighterPlanet.billing.emission_estimate_service.bill do |query|
      query.certified = true
      query.key = params['key']
      query.timeframe = Timeframe.this_year
      query.params = params
      query.url = params['url']
      query.emitter = 'Automobile'
      if params['key'] and params['url']
        query.remote_ip = params['remote_ip']
        query.referer = params['referer']
      end
      query.emission = emission
      execution_id = query.execution_id # so we can look at it
    end
    sleep 1
    stored_query = ::BrighterPlanet.billing.emission_estimate_service.queries.find_one(:execution_id => execution_id)
    assert_equal 'EmissionEstimateService', stored_query.service.name
    assert_equal true, stored_query.certified
    assert_equal 'Automobile', stored_query.emitter
    assert_equal emission, stored_query.emission
  end

  def test_012_delayed_store_to_mongo
    params = { 'make' => 'Nissan', 'key' => 'hiseamus', 'url' => 'http://carbon.brighterplanet.com/automobiles.json?make=Nissan' }
    emission = 29102
    execution_id = nil
    assert_false ::BrighterPlanet.billing.config.disable_caching?
    ::BrighterPlanet.billing.emission_estimate_service.bill do |query|
      query.certified = false
      query.timeframe = Timeframe.this_year
      query.key = params['key']
      query.params = params
      query.url = params['url']
      query.emitter = 'Automobile'
      if params['key'] and params['url']
        query.remote_ip = params['remote_ip']
        query.referer = params['referer']
      end
      query.emission = emission
      execution_id = query.execution_id
    end
    assert_nil ::BrighterPlanet.billing.emission_estimate_service.queries.find_one(:execution_id => execution_id)
    ::BrighterPlanet.billing.synchronize
    sleep 1
    stored_query = ::BrighterPlanet.billing.emission_estimate_service.queries.find_one(:execution_id => execution_id)
    assert_equal 'EmissionEstimateService', stored_query.service.name
    assert_equal false, stored_query.certified
    assert_equal 'Automobile', stored_query.emitter
    assert_equal emission, stored_query.emission
  end
  
  def test_013_catches_errors_with_hoptoad
    ::BrighterPlanet.billing.config.disable_hoptoad = false
    assert_raises(::BrighterPlanet::Billing::ReportedExceptionToHoptoad) do
      ::BrighterPlanet.billing.emission_estimate_service.bill do |query|
        raise StandardError
      end
    end
  end
  
  def test_014_catches_errors_without_hoptoad
    assert_raises(StandardError) do
      ::BrighterPlanet.billing.emission_estimate_service.bill do |query|
        raise StandardError
      end
    end
  end
  
  def test_015_allows_certain_errors_through
    ::BrighterPlanet.billing.config.disable_hoptoad = false
    require 'leap'
    ::BrighterPlanet.billing.config.allowed_exceptions.push ::Leap::NoSolutionError
    assert_raises(::Leap::NoSolutionError) do
      ::BrighterPlanet.billing.emission_estimate_service.bill do |query|
        raise ::Leap::NoSolutionError
      end
    end
  end
  
  def test_016_can_immediately_get_execution_id
    ::BrighterPlanet.billing.emission_estimate_service.bill do |query|
      assert_equal ::String, query.execution_id.class
    end
  end
  
  def test_017_really_runs_block
    confirmation = catch :i_ran do
      ::BrighterPlanet.billing.emission_estimate_service.bill do |query|
        throw :i_ran, :yes_i_did
      end
    end
    assert_equal :yes_i_did, confirmation
  end
  
  def test_018_synchronization
    assert BrighterPlanet::Billing::Synchronization.respond_to? :perform
  end
end
