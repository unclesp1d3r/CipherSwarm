class Api::V1::Client::AttacksController < Api::V1::BaseController
  resource_description do
    short "Attacks"
    formats [ "json" ]
    desc "The attacks resource allows you to manage the attacks that are available to the agents."
    error 400, "Bad request. The request was invalid."
    error 401, "Unauthorized. The request was not authorized."
    error 404, "Not found. The requested resource was not found."
    header "Authorization", "The token to authenticate the agent with.", required: true
  end

  def_param_group :attack do
    param :id, Integer, desc: "The ID of the attack."
    param :attack_mode, [ "straight", "combination", "brute_force", "hybrid", "prince", "table_lookup" ], desc: "The attack mode."
    param :mask, String, desc: "The mask to use for the attack.", required: false
    param :increment_mode, [ true, false ], desc: "The increment mode.", required: false
    param :increment_minimum, Integer, desc: "The minimum increment.", required: false
    param :increment_maximum, Integer, desc: "The maximum increment.", required: false
    param :optimized, [ true, false ], desc: "Whether the attack is optimized.", required: false
    param :slow_candidate_generators, [ true, false ], desc: "Whether the attack uses slow candidate generators.", required: false
    param :workload_profile, :number, desc: "The workload profile.", required: false
    param :disable_markov, [ true, false ], desc: "Whether the attack disables Markov.", required: false
    param :classic_markov, [ true, false ], desc: "Whether the attack uses classic Markov.", required: false
    param :markov_threshold, :number, desc: "The Markov threshold.", required: false
    param :left_rule, String, desc: "The left rule.", required: false
    param :right_rule, String, desc: "The right rule.", required: false
    param :custom_charset_1, String, desc: "The first custom charset.", required: false
    param :custom_charset_2, String, desc: "The second custom charset.", required: false
    param :custom_charset_3, String, desc: "The third custom charset.", required: false
    param :custom_charset_4, String, desc: "The fourth custom charset.", required: false
    param :cracker_id, Integer, desc: "The ID of the cracker to use for the attack.", required: true
    param :hash_list_id, Integer, desc: "The ID of the hash list to use for the attack.", required: true
    param :word_lists, Array, desc: "The word lists to use for the attack.", required: true do
      param :id, Integer, desc: "The ID of the word list."
      param :download_url, String, desc: "The URL to download the word list."
      param :checksum, String, desc: "The checksum of the word list."
      param :file_name, String, desc: "The name of the word list file."
    end
    param :rule_lists, Array, desc: "The rule lists to use for the attack.", required: true do
      param :id, Integer, desc: "The ID of the rule list."
      param :download_url, String, desc: "The URL to download the rule list."
      param :checksum, String, desc: "The checksum of the rule list."
      param :file_name, String, desc: "The name of the rule list file."
    end
    param :hash_mode, Integer, desc: "The hash mode of the hash list."
    param :hash_list_url, String, desc: "The URL to download the hash list."
    param :hash_list_checksum, String, desc: "The checksum of the hash list."
    param :url, String, desc: "The URL of the attack."
  end

  api!
  param :id, :number, required: true, desc: "The ID of the attack to retrieve."
  description "Retrieves the attack with the specified ID."
  returns code: 200, desc: "The attack was successfully retrieved." do
    param_group :attack
  end
  returns code: 404, desc: "The attack was not found."

  def show
    @attack = Attack.find(params[:id])
  end

  api! "Returns the hash list for the attack."
  param :id, :number, required: true, desc: "The ID of the attack to retrieve the hash list for."
  description "Retrieves the hash list for the attack with the specified ID."
  returns code: 200, desc: "Initiates a download of the hash list."
  returns code: 404, desc: "The attack was not found." do
    property :error, String, desc: "The error message."
  end
  returns code: 401, desc: "Unauthorized. The request was not authorized."
  error code: 404, desc: "Not found. The requested resource was not found."
  error code: 401, desc: "Unauthorized. The request was not authorized."

  def hash_list
    @attack = Attack.find(params[:id])
    if @attack.nil?
      render json: { error: "Attack not found." }, status: :not_found
      return
    end
    send_data @attack.campaign.hash_list.uncracked_list,
              filename: "#{@attack.campaign.hash_list.id}.txt"
  end
end
