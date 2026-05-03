module CopilotHistory
  module Api
    module Types
      module SessionLookupResult
        class Found
          UNSET = Object.new.freeze
          private_constant :UNSET

          def self.members
            [ :detail_payload ]
          end

          attr_reader :detail_payload

          def initialize(detail_payload: nil, root: UNSET, session: UNSET)
            @detail_payload = detail_payload
            @root = root unless root.equal?(UNSET)
            @session = session unless session.equal?(UNSET)
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
            return @root if name == :root && legacy_root?
            return @session if name == :session && legacy_session?

            super
          end

          def respond_to_missing?(name, include_private = false)
            (name == :root && legacy_root?) ||
              (name == :session && legacy_session?) ||
              super
          end

          private

          def legacy_root_for_equality
            legacy_root? ? @root : UNSET
          end

          def legacy_session_for_equality
            legacy_session? ? @session : UNSET
          end

          def legacy_root?
            instance_variable_defined?(:@root)
          end

          def legacy_session?
            instance_variable_defined?(:@session)
          end
        end

        class NotFound < Data.define(:session_id)
        end
      end
    end
  end
end
