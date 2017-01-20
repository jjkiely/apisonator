module ThreeScale
  module Backend
    class EventStorage
      PING_TTL    = 60
      EVENT_TYPES = [:first_traffic, :first_daily_traffic, :alert]

      class << self
        include StorageHelpers
        include Backend::Logging

        def store(type, object)
          fail InvalidEventType, type unless EVENT_TYPES.member?(type)
          new_id = storage.incrby(events_id_key, 1)
          event  = { id: new_id, type: type, timestamp: Time.now.utc, object: object }
          storage.zadd(events_queue_key, event[:id], encode(event))
        end

        def list
          raw_events = storage.zrevrange(events_queue_key, 0, -1)
          raw_events.map { |raw_event| decode_event(raw_event) }.reverse
        end

        def delete_range(to_id)
          to_id = to_id.to_i
          if to_id > 0
            storage.zremrangebyscore(events_queue_key, 0, to_id)
          else
            0
          end
        end

        def delete(id)
          id = id.to_i
          (id > 0) ? storage.zremrangebyscore(events_queue_key, id, id) : 0
        end

        def size
          storage.zcard(events_queue_key)
        end

        def ping_if_not_empty
          if events_hook_configured? && pending_ping?
            begin
              request_to_events_hook
              return true
            rescue Exception => e
              logger.notify(e)
              return nil
            end
          end

          false
        end

        private

        def events_queue_key
          "events/queue".freeze
        end

        def events_ping_key
          "events/ping".freeze
        end

        def events_id_key
          "events/id".freeze
        end

        def events_hook_configured?
          return @events_hook_configured unless @events_hook_configured.nil?
          events_hook = ThreeScale::Backend.configuration.events_hook
          @events_hook_configured = events_hook && !events_hook.empty?
        end

        def request_to_events_hook
          Net::HTTP.post_form(
            events_hook_uri,
            secret: ThreeScale::Backend.configuration.events_hook_shared_secret,
          )
        end

        def events_hook_uri
          @events_hook_uri ||= URI(ThreeScale::Backend.configuration.events_hook)
        end

        def expire_last_ping
          storage.expire(events_ping_key, PING_TTL)
        end

        def pending_ping?
          ## the queue is not empty and more than timeout has passed
          ## since the front-end was notified
          events_set_size, ping_key_value = storage.pipelined do
            storage.zcard(events_queue_key)
            storage.incr(events_ping_key)
          end

          return false unless ping_key_value.to_i == 1
          expire_last_ping
          events_set_size > 0
        end

        # TODO: Remove this method. It's used only in tests and there it's
        # possible to mock a constant.
        def redef_without_warning(const, value)
          remove_const(const)
          const_set(const, value)
        end

        def decode_event(raw_event)
          event = decode(raw_event)

          # decode only symbolizes keys and parse timestamp for first level
          obj = event[:object]
          if obj
            event[:object] = obj.symbolize_keys
            ts = event[:object][:timestamp]
            event[:object][:timestamp] = Time.parse_to_utc(ts) if ts
          end

          event
        end
      end
    end
  end
end
