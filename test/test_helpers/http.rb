module TestHelpers
  module HTTP
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      VALID_CTYPES = ['application/x-www-form-urlencoded', 'multipart/form-data', '', nil].freeze
      INVALID_CTYPES = ['image/invalid', 'some_content_type', 'application/xml+invalid']
      private_constant :VALID_CTYPES, :INVALID_CTYPES

      private

      def test_post(endpoint, params = {}, ctypes: VALID_CTYPES, invalid_ctypes: INVALID_CTYPES)
        (Array(invalid_ctypes) - Array(ctypes)).each do |ctype|
          test "POST to #{endpoint} returns invalid content type error with #{ctype.inspect}" do
            post endpoint, params, 'CONTENT_TYPE' => ctype
            error = Nokogiri::XML(last_response.body).at('error:root')
            assert_not_nil error
            assert_equal 'content_type_invalid', error['code']
            assert_equal "invalid Content-Type: #{ctype}", error.content
            assert_equal 400, last_response.status
          end
        end

        Array(ctypes).each do |ctype|
          test "POST to #{endpoint} does not invalid content type error with #{ctype.inspect}" do
            post endpoint, params, 'CONTENT_TYPE' => ctype
            error = Nokogiri::XML(last_response.body).at('error:root')
            if error
              assert_not_equal 'content_type_invalid', error['code']
              assert_not_equal "invalid Content-Type: #{ctype}", error.content
            end
          end
        end

      end
    end
  end
end
