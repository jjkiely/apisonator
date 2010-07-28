require File.dirname(__FILE__) + '/../test_helper'

class ErrorsTest < Test::Unit::TestCase
  def test_xml_serialization
    exception = ProviderKeyInvalid.new('moo')

    doc = Nokogiri::XML(exception.to_xml)

    error = doc.at('error:root')
    assert_not_nil error
    assert_equal 'provider_key_invalid', error['code']
    assert_equal 'provider key "moo" is invalid', error.content
  end

  def test_code
    assert_equal 'user_key_invalid', UserKeyInvalid.code
    assert_equal 'user_key_invalid', UserKeyInvalid.new('foo').code
  end

  def test_message_of_user_key_invalid
    error = UserKeyInvalid.new('foo')
    assert_equal 'user key "foo" is invalid', error.message
  end
  
  def test_message_of_provider_key_invalid
    error = ProviderKeyInvalid.new('foo')
    assert_equal 'provider key "foo" is invalid', error.message
  end
  
  def test_message_of_metric_invalid
    error = MetricInvalid.new('foos')
    assert_equal 'metric "foos" is invalid', error.message
  end
  
  def test_message_of_usage_value_invalid_when_the_value_is_empty
    error = UsageValueInvalid.new('hits', nil)
    assert_equal %Q(usage value for metric "hits" can't be empty), error.message
    
    error = UsageValueInvalid.new('hits', '')
    assert_equal %Q(usage value for metric "hits" can't be empty), error.message
    
    error = UsageValueInvalid.new('hits', '  ')
    assert_equal %Q(usage value for metric "hits" can't be empty), error.message
  end
  
  def test_message_of_usage_value_invalid_when_the_value_is_not_empty
    error = UsageValueInvalid.new('hits', 'really a lot')
    assert_equal %Q(usage value "really a lot" for metric "hits" is invalid), error.message
  end

  def test_message_of_contract_not_active_error
    error = ContractNotActive.new
    assert_equal 'contract is not active', error.message
  end
  
  def test_message_of_limits_exceeded_error
    error = LimitsExceeded.new
    assert_equal 'usage limits are exceeded', error.message
  end
end
