require '3scale/backend/stats/redshift_adapter'

module ThreeScale
  module Backend
    module Stats
      class RedshiftJob < BackgroundJob
        @queue = :stats

        class << self
          def perform_logged(lock_key, _)
            begin
              latest_time_inserted = RedshiftAdapter.insert_data
              ok = true
              msg = job_ok_msg(latest_time_inserted)
            rescue Exception => e
              ok = false
              msg = e.message
            end

            RedshiftImporter.job_finished(lock_key)
            [ok, msg]
          end

          private

          def job_ok_msg(time_utc)
            "Events imported correctly. Latest ones are from: #{time_utc.to_s}"
          end
        end
      end
    end
  end
end
