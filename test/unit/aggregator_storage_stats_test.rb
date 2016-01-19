require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
require_relative '../../lib/3scale/backend/stats/tasks'

class AggregatorStorageStatsTest < Test::Unit::TestCase
  include TestHelpers::StorageKeys
  include TestHelpers::AuthorizeAssertions
  include TestHelpers::Sequences
  include TestHelpers::Fixtures
  include Backend::StorageHelpers

  def setup
    @storage = Storage.instance(true)
    @storage.flushdb
    seed_data

    Stats::Storage.enable!
    Memoizer.reset!

    Resque.reset!
    Memoizer.reset!

    reset_aggregator_prior_bucket!

    ## stubbing the airbreak, not working on tests
    Airbrake.stubs(:notify).returns(true)
  end

  def stats_bucket_size
    Stats::Aggregator.send(:stats_bucket_size)
  end

  test 'process increments_all_stats_counters' do
    Stats::Aggregator.process([transaction_with_response_code])

    assert_equal '1', @storage.get(service_key(1001, 3001, :month,  '20100501'))
    assert_equal '1', @storage.get(response_code_key(1001, '200', :month,  '20100501'))
    assert_equal '1', @storage.get(response_code_key(1001, '2XX', :month,  '20100501'))

    assert_equal '1', @storage.get(service_key(1001, 3001, :day,    '20100507'))
    assert_equal '1', @storage.get(response_code_key(1001, '200', :day,    '20100507'))
    assert_equal '1', @storage.get(response_code_key(1001, '2XX', :day,    '20100507'))

    assert_equal '1', @storage.get(service_key(1001, 3001, :hour,   '2010050713'))
    assert_equal '1', @storage.get(response_code_key(1001, '200', :hour,   '2010050713'))
    assert_equal '1', @storage.get(response_code_key(1001, '2XX', :hour,   '2010050713'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :year,   '20100101'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :year,   '20100101'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :year,   '20100101'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :month,  '20100501'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :month,  '20100501'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :month,  '20100501'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :day,    '20100507'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :day,    '20100507'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :day,    '20100507'))

    assert_equal '1', @storage.get(application_key(1001, 2001, 3001, :hour,   '2010050713'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '200', :hour,   '2010050713'))
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :hour,   '2010050713'))
  end


  test 'aggregates response codes incrementing 2XX for unknown 209 response '  do
    transaction_with_unknown_response_code = transaction_with_response_code(209)
    Stats::Aggregator.process([transaction_with_unknown_response_code])
    assert_equal '1', @storage.get(app_response_code_key(1001, 2001, '2XX', :hour,   '2010050713'))
    assert_equal nil, @storage.get(app_response_code_key(1001, 2001, '209', :hour,   '2010050713'))
  end

  test 'when storage stats is disabled nothing gets logged' do
    Stats::Storage.disable!
    ## the flag to know if storage stats is enabled is memoized
    Memoizer.reset!

    Stats::Aggregator.process(Array.new(10, default_transaction))
    assert_equal 0, Stats::Info.pending_buckets.size
  end

  test 'applications with end user plans (user_id) get recorded properly' do
    default_user_plan_id = next_id
    default_user_plan_name = "user plan mobile"
    timestamp = default_transaction_timestamp

    service = Service.save!(provider_key: @provider_key, id: next_id)
    Service.stubs(:load_by_id).returns(service)
    service.stubs :user_add

    service.user_registration_required = false
    service.default_user_plan_name = default_user_plan_name
    service.default_user_plan_id = default_user_plan_id
    service.save!

    application = Application.save(service_id:    service.id,
                                   id:            next_id,
                                   state:         :active,
                                   plan_id:       @plan_id,
                                   plan_name:     @plan_name,
                                   user_required: true)

    transaction = Transaction.new(service_id:     service.id,
                                  application_id: application.id,
                                  timestamp:      timestamp,
                                  usage:          { @metric_hits.id => 5 },
                                  user_id:        "user_id_xyz")

    Stats::Aggregator.process([transaction])

    assert_equal '5', @storage.get(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal '5', @storage.get(application_key(service.id, application.id, @metric_hits.id, :month,   '20100501'))
    assert_equal '5', @storage.get(application_key(service.id, application.id, @metric_hits.id, :eternity))

    assert_equal '5', @storage.get(service_key(service.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal '5', @storage.get(service_key(service.id, @metric_hits.id, :month,   '20100501'))
    assert_equal '5', @storage.get(service_key(service.id, @metric_hits.id, :eternity))

    assert_equal '5', @storage.get(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :hour,   '2010050713'))
    assert_equal '5', @storage.get(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :month,   '20100501'))
    assert_equal '5', @storage.get(end_user_key(service.id, "user_id_xyz", @metric_hits.id, :eternity))

    transaction = Transaction.new(service_id:     service.id,
                                  application_id: application.id,
                                  timestamp:      timestamp,
                                  usage:          { @metric_hits.id => 4 },
                                  user_id:        "another_user_id_xyz")

    Stats::Aggregator.process([transaction])

    assert_equal '9', @storage.get(application_key(service.id, application.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal '9', @storage.get(application_key(service.id, application.id, @metric_hits.id, :month,   '20100501'))
    assert_equal '9', @storage.get(application_key(service.id, application.id, @metric_hits.id, :eternity))

    assert_equal '9', @storage.get(service_key(service.id, @metric_hits.id, :hour,   '2010050713'))
    assert_equal '9', @storage.get(service_key(service.id, @metric_hits.id, :month,   '20100501'))
    assert_equal '9', @storage.get(service_key(service.id, @metric_hits.id, :eternity))

    assert_equal '4', @storage.get(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :hour,   '2010050713'))
    assert_equal '4', @storage.get(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :month,   '20100501'))
    assert_equal '4', @storage.get(end_user_key(service.id, "another_user_id_xyz", @metric_hits.id, :eternity))
  end


  test 'transactions with end_user plans (user_id) with response codes get properly aggregated' do
    default_user_plan_id = next_id
    default_user_plan_name = "user plan mobile"
    timestamp = default_transaction_timestamp

    service = Service.save!(provider_key: @provider_key, id: next_id)
    Service.stubs(:load_by_id).returns(service)
    service.stubs :user_add

    service.user_registration_required = false
    service.default_user_plan_name = default_user_plan_name
    service.default_user_plan_id = default_user_plan_id
    service.save!

    application = Application.save(service_id:    service.id,
                                   id:            next_id,
                                   state:         :active,
                                   plan_id:       @plan_id,
                                   plan_name:     @plan_name,
                                   user_required: true)

    transaction = Transaction.new(service_id:     service.id,
                                  application_id: application.id,
                                  timestamp:      timestamp,
                                  usage:          { @metric_hits.id => 1 },
                                  response_code: 200,
                                  user_id:        "user_id_xyz")

    Stats::Aggregator.process([transaction])

    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '2XX', :hour,   '2010050713'))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '2XX', :month,   '20100501'))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '2XX', :eternity))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '200', :hour,   '2010050713'))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '200', :month,   '20100501'))
    assert_equal '1', @storage.get(end_user_response_code_key(service.id, "user_id_xyz", '200', :eternity))
  end

  test 'delete all buckets and keys' do
    timestamp = Time.now.utc - 1000

    5.times do
      Timecop.freeze(timestamp) do
        Stats::Aggregator.process([default_transaction])
      end

      timestamp += stats_bucket_size
    end

    assert_equal 5, @storage.keys('keys_changed:*').size
    assert_equal 0, @storage.keys('copied:*').size
    assert_equal 5, Stats::Info.pending_buckets.size

    Stats::Tasks.delete_all_buckets_and_keys_only_as_rake!(silent: true)

    assert_equal 0, @storage.keys('copied:*').size
    assert_equal 0, @storage.keys('keys_changed:*').size
    assert_equal 0, Stats::Info.pending_buckets.size
  end

  test 'process updates application set' do
    Stats::Aggregator.process([default_transaction])

    assert_equal ['2001'], @storage.smembers("stats/{service:1001}/cinstances")
  end

  test 'process does not update service set' do
    assert_no_change of: lambda { @storage.smembers('stats/services') } do
      Stats::Aggregator.process([default_transaction])
    end
  end

  test 'process sets expiration time for volatile keys' do
    Stats::Aggregator.process([default_transaction])

    key = application_key('1001', '2001', '3001', :minute, 201005071323)
    ttl = @storage.ttl(key)

    assert ttl >  0
    assert ttl <= 180
  end
end
