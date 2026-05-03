module CopilotHistory
  module Api
    module Types
      module SessionLookupResult
        class Found
          def self.members
            [ :detail_payload ]
          end

          attr_reader :detail_payload

          def initialize(detail_payload: nil, root: nil, session: nil)
            @detail_payload = detail_payload
            @root = root
            @session = session
          end

          def ==(other)
            other.is_a?(self.class) &&
              detail_payload == other.detail_payload &&
              legacy_root_for_equality == other.send(:legacy_root_for_equality) &&
              legacy_session_for_equality == other.send(:legacy_session_for_equality)
          end
          alias eql? ==

          def hash
            [ self.class, detail_payload, legacy_root_for_equality, legacy_session_for_equality ].hash
          end

          def method_missing(name, ...)
            return @root if name == :root && defined?(@root)
            return @session if name == :session && defined?(@session)

            super
          end

          private

          def legacy_root_for_equality
            @root
          end

          def legacy_session_for_equality
            @session
          end
        end

        class NotFound < Data.define(:session_id)
        end
      end
    end
  end
end
