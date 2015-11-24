module ThreeScale
  module Backend
    class Error < RuntimeError
      def to_xml(options = {})
        xml = Builder::XmlMarkup.new
        xml.instruct! unless options[:skip_instruct]
        xml.error(message, :code => code)

        xml.target!
      end

      def code
        self.class.code
      end

      def self.code
        underscore(name[/[^:]*$/])
      end

      # TODO: move this over to some utility module.
      def self.underscore(string)
        # Code stolen from ActiveSupport
        string.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
               gsub(/([a-z\d])([A-Z])/,'\1_\2').
               downcase
      end
    end

    NotFound = Class.new(Error)
    Invalid  = Class.new(Error)

    class ApplicationKeyInvalid < Error
      def initialize(key)
        if key.blank?
          super %(application key is missing)
        else
          super %(application key "#{key}" is invalid)
        end
      end
    end

    class ApplicationHasInconsistentData < Error
      def initialize(id, user_key)
        super %(Application id="#{id}" with user_key="#{user_key}" has inconsistent data and could not be saved)
      end
    end

    class ApplicationNotFound < NotFound
      def initialize(id = nil)
        super %(application with id="#{id}" was not found)
      end
    end

    class AccessTokenInvalid < NotFound
      def initialize(id = nil, user_id = nil)
        super %(access_token "#{id}" is invalid#{" for user_id=#{user_id}" if user_id}: expired or never defined)
      end
    end

    class AccessTokenAlreadyExists < Error
      def initialize(id = nil)
        super %(access_token "#{id}" already exists)
      end
    end

    class AccessTokenStorageError < Error
      def initialized(id = nil)
        super %(storage error when saving access_token "#{id}")
      end
    end

    class ApplicationNotActive < Error
      def initialize
        super %(application is not active)
      end
    end

    class OauthNotEnabled < Error
      def initialize
        super %(oauth is not enabled)
      end
    end

    class RedirectURIInvalid < Error
      def initialize(uri)
        super %(redirect_uri "#{uri}" is invalid)
      end
    end

    class RedirectURLInvalid < Error
      def initialize(url)
        super %(redirect_url "#{url}" is invalid)
      end
    end

    class LimitsExceeded < Error
      def initialize
        super %(usage limits are exceeded)
      end
    end

    class ProviderKeyInvalid < Error
      def initialize(key)
        super %(provider key "#{key}" is invalid)
      end
    end

    class ServiceIdInvalid < Error
      def initialize(id)
        super %(service id "#{id}" is invalid)
      end
    end

    class MetricInvalid < Error
      def initialize(metric_name)
        super %(metric "#{metric_name}" is invalid)
      end
    end

    class ReferrerFilterInvalid < Invalid
    end

    class NotValidData < Invalid
      def initialize
        super 'all data must be valid UTF8'
      end
    end

    class BadRequest < Invalid
      def initialize
        super 'request contains syntax errors, should not be repeated without modification'
      end
    end

    class ReferrerFiltersMissing < Error
      def initialize
        super 'referrer filters are missing'
      end
    end

    class ReferrerNotAllowed < Error
      def initialize(referrer)
        if referrer.blank?
          super %(referrer is missing)
        else
          super %(referrer "#{referrer}" is not allowed)
        end
      end
    end

    class RequiredParamsMissing < Invalid
      def initialize
        super 'missing required parameters'
      end
    end

    class BucketMissing < Invalid
      def initialize
        super 'bucket is missing'
      end
    end

    class UsageValueInvalid < Error
      def initialize(metric_name, value)
        if !value.is_a?(String) || value.blank?
          super %(usage value for metric "#{metric_name}" can not be empty)
        else
          super %(usage value "#{value}" for metric "#{metric_name}" is invalid)
        end
      end
    end

    class UnsupportedApiVersion < Error
    end

    # new errors for the user limiting
    class UserNotDefined < Error
      def initialize(id)
        super %(application with id="#{id}" requires a user (user_id))
      end
    end

    class ReportTimestampNotWithinRange < Error
      def initialize(max_seconds)
        super %(report jobs cannot update metrics older than #{max_seconds} seconds)
      end
    end

    class UserRequiresRegistration < Error
      def initialize(service_id, user_id)
        super %(user with user_id="#{user_id}" requires registration to use service with id="#{service_id}")
      end
    end

    class ServiceCannotUseUserId < Error
      def initialize(service_id)
        super %(service with service_id="#{service_id}" does not have access to end user plans, user_id is not allowed)
      end
    end

    class ServiceLoadInconsistency < Error
      def initialize(service_id, other_service_id)
        super %(service.load_by_id with id="#{service_id}" loaded the service with id="#{other_service_id}")
      end
    end

    class ServiceRequiresDefaultUserPlan < Error
      def initialize
        super 'Services without the need for registered users require a default user plan'
      end
    end

    class ServiceIsDefaultService < Error
      def initialize(id = nil)
        super %(Service id="#{id}" is the default service, cannot be removed)
      end
    end

    class ServiceRequiresRegisteredUser < Error
      def initialize(id = nil)
        super %(Service id="#{id}" requires users to be registered beforehand)
      end
    end

    class UserRequiresUsername < Error
      def initialize
        super %(User requires username)
      end
    end

    class UserRequiresValidService < Error
      def initialize
        super %(User requires a valid service, the service does not exist)
      end
    end

    class UserRequiresDefinedPlan < Error
      def initialize
        super %(User requires a defined plan)
      end
    end

    class InvalidProviderKeys < Error
      def initialize
        super %(Provider keys are not valid, must be not nil and different)
      end
    end

    class ProviderKeyExists < Error
      def initialize(key)
        super %(Provider key="#{key}" already exists)
      end
    end

    class ProviderKeyNotFound < Error
      def initialize(key)
        super %(Provider key="#{key}" does not exist)
      end
    end

    class InvalidEventType < Error
      def initialize(type)
        super %(Event type "#{type}" is invalid")
      end
    end

    # Legacy API support

    class AuthenticationError < Error
      def initialize
        super %(either app_id or user_key is allowed, not both)
      end
    end

    class UserKeyInvalid < Error
      def initialize(key)
        super %(user key "#{key}" is invalid)
      end
    end
  end
end
