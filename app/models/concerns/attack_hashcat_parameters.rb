# frozen_string_literal: true

# SPDX-FileCopyrightText:  2024 UncleSp1d3r
# SPDX-License-Identifier: MPL-2.0

# Provides methods for building Hashcat command line parameters.
#
# This concern extracts parameter-building logic from the Attack model to improve
# organization and testability.
#
# @example
#   attack.hashcat_parameters
#   # => "-a 0 -O -w 3 wordlist.txt"
module AttackHashcatParameters
  extend ActiveSupport::Concern

  ##
  # Builds a string of parameters for the Hashcat tool based on various attack options.
  #
  # Gathers and compiles attack-specific parameters, configuration settings, and additional flags
  # depending on the current attributes of the attack instance. The result is a single, concatenated
  # string of parameters suitable for executing Hashcat.
  #
  # - Includes the attack mode parameter derived from the `attack_mode` attribute.
  # - Adds Markov mode parameters and flags, such as thresholds or disabling settings, if applicable.
  # - Enables optimization or candidate generation configuration if flagged.
  # - Constructs increment mode parameters when `increment_mode` is enabled.
  # - Assembles custom character set parameters and file inputs from the instance's related lists.
  # - Assigns the workload profile based on the current configuration.
  #
  # @return [String] the composed string of Hashcat parameters.
  def hashcat_parameters
    parameters = []
    parameters << attack_mode_param
    parameters << "-O" if optimized
    parameters << increment_mode_param if increment_mode
    parameters << "--markov-disable" if disable_markov
    parameters << "--markov-classic" if classic_markov
    parameters << "-t #{markov_threshold}" if markov_threshold.present? && markov_threshold.positive?
    parameters << "-S" if slow_candidate_generators
    parameters << custom_charset_params
    parameters << "-w #{workload_profile}"
    parameters << file_params
    parameters.compact.join(" ")
  end

  private

  # Generates the attack mode parameter for Hashcat.
  #
  # @return [String] the attack mode parameter.
  def attack_mode_param
    "-a #{Attack.attack_modes[attack_mode]}"
  end

  # Generates the custom charset parameter for Hashcat.
  #
  # @param index [Integer] the index of the custom charset (1 to 4).
  # @return [String, nil] the custom charset parameter if present, otherwise nil.
  def charset_param(index)
    value = send("custom_charset_#{index}")
    "-#{index} #{value}" if value.present?
  end

  # Generates the custom charset parameters for Hashcat.
  #
  # This method iterates through the custom charsets (1 to 4) and generates
  # the corresponding parameters for each charset that is present.
  #
  # @return [String] A string of custom charset parameters.
  def custom_charset_params
    (1..4).map { |i| charset_param(i) }.compact.join(" ")
  end

  # Generates the file parameters for Hashcat.
  #
  # This method retrieves the filenames of the word list and mask list,
  # and includes the rule list file if present.
  #
  # @return [String] A string of file parameters.
  def file_params
    [word_list, mask_list].compact.map { |list| list.file.filename }.join(" ") +
      (rule_list.present? ? " -r #{rule_list.file.filename}" : "")
  end

  # Generates the increment mode parameters for Hashcat.
  #
  # This method constructs the parameters for enabling increment mode in Hashcat,
  # including the minimum and maximum increment values.
  #
  # @return [String] A string of increment mode parameters.
  def increment_mode_param
    ["--increment", "--increment-min #{increment_minimum}", "--increment-max #{increment_maximum}"].join(" ")
  end
end
