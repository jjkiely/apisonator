require '3scale/backend/stats/keys'
require '3scale/backend/transaction'
require '3scale/backend/stats/aggregators/base'

module ThreeScale
  module Backend
    module Stats
      module Aggregators
        class ResponseCode
          class << self
            include Keys
            include Base

            def aggregate(transaction, bucket = nil)
              keys_for_multiple_codes = keys_for_response_code(transaction)
              timestamp = transaction.timestamp

              # For now, we are not interested in storing response codes in
              # buckets, that is the reason why set bucket to nil.
              bucket = nil

              keys_for_multiple_codes.each do |keys|
                aggregate_values(1, timestamp, keys, :incrby, bucket)
              end
            end


            protected
            def keys_for_response_code(transaction)
              response_code = transaction.extract_response_code
              return {} unless response_code
              values = values_to_inc(response_code)
              values.flat_map do |code|
                Keys.transaction_keys(transaction, :response_code, code)
              end
            end

            def values_to_inc(response_code)
              keys = [Stats::CodesCommons.get_http_code_group(response_code)]
              keys << response_code.to_s if tracked_code?(response_code)
              keys
            end

            def tracked_code?(code)
              Stats::CodesCommons::TRACKED_CODES.include?(code)
            end
          end
        end
      end
    end
  end
end
