module Anthropic
  module Bedrock
    # Limited beta surface for Amazon Bedrock.
    #
    # Official Bedrock SDKs (Python / TypeScript / Ruby) expose
    # `client.beta.messages` but not the full Managed Agents surface
    # (files, dreams, tunnels, deployments, etc.). Accessors other than
    # `#messages` raise `NotImplementedError`.
    class Beta < Anthropic::Beta
      def initialize(client : Client)
        super(client)
      end

      def messages : Anthropic::BetaMessages
        Anthropic::BetaMessages.new(@client)
      end

      def models : Anthropic::BetaModels
        not_supported("models")
      end

      def files : Anthropic::BetaFiles
        not_supported("files")
      end

      def skills : Anthropic::BetaSkills
        not_supported("skills")
      end

      def user_profiles : Anthropic::BetaUserProfiles
        not_supported("user_profiles")
      end

      def environments : Anthropic::BetaEnvironments
        not_supported("environments")
      end

      def memory_stores : Anthropic::BetaMemoryStores
        not_supported("memory_stores")
      end

      def sessions : Anthropic::BetaSessions
        not_supported("sessions")
      end

      def webhooks : Anthropic::BetaWebhooks
        not_supported("webhooks")
      end

      def agents : Anthropic::BetaAgents
        not_supported("agents")
      end

      def vaults : Anthropic::BetaVaults
        not_supported("vaults")
      end

      def deployments : Anthropic::BetaDeployments
        not_supported("deployments")
      end

      def deployment_runs : Anthropic::BetaDeploymentRuns
        not_supported("deployment_runs")
      end

      def dreams : Anthropic::BetaDreams
        not_supported("dreams")
      end

      def tunnels : Anthropic::BetaTunnels
        not_supported("tunnels")
      end

      private def not_supported(feature : String) : NoReturn
        raise NotImplementedError.new(
          "Bedrock does not support beta.#{feature}. Only client.beta.messages is available " \
          "(matching the official Anthropic Bedrock SDKs)."
        )
      end
    end
  end
end
