require 'helper'

class TestEmissionEstimateService < Test::Unit::TestCase
  def test_000_bill_for_a_query
    query = bill_flight_query
    retrieved_query = BrighterPlanet::Billing.emission_estimate_service.queries.find_one :execution_id => query.execution_id
    # the full floating-point precision isn't saved
    assert(query.emission - retrieved_query.emission < 0.001)
    assert_equal query.certified, retrieved_query.certified
  end
  
  def test_001_sample_query_results
    bill_flight_query
    flight_sample = BrighterPlanet::Billing.emission_estimate_service.queries.sample({:emitter => 'Flight'})
    
    mean_emission = flight_sample.mean(:emission)
    assert(mean_emission > 100)
    assert(mean_emission < 801)
    
    variation_emission = flight_sample.variation(:emission)
    assert(variation_emission > 1)
    assert(variation_emission < 100)
  end
    
  private
  
  def bill_flight_query
    query = BrighterPlanet::Billing.emission_estimate_service.bill do |query|
      query.key = 'TestEmissionEstimateService#bill_flight_query'
      query.emitter = 'Flight'
      query.certified = false
      query.emission = rand(800) + rand
      query.color = [ :red, :blue ].sort_by { rand }[0]
    end
    BrighterPlanet::Billing.synchronize
    sleep 5
    query
  end
end
