class CreateOperations < ActiveRecord::Migration[7.1]
  def change
    create_table :operations do |t|
      t.string :name, null: false, default: "", comment: "Attack name"
      t.text :description, null: true, default: "", comment: "Attack description"
      t.integer :attack_mode, null: false, default: 0, index: true, comment: "Hashcat attack mode"
      t.string :mask, null: true, default: "", comment: "Hashcat mask (e.g. ?a?a?a?a?a?a?a?a)"
      t.boolean :increment_mode, null: false, default: false, comment: "Is the attack using increment mode?"
      t.integer :increment_minimum, null: true, default: 0, comment: "Hashcat increment minimum"
      t.integer :increment_maximum, null: true, default: 0, comment: "Hashcat increment maximum"
      t.boolean :optimized, null: false, default: false, comment: "Is the attack optimized?"
      t.boolean :slow_candidate_generators, null: false, default: false, comment: "Are slow candidate generators enabled?"
      t.integer :workload_profile, null: false, default: 3, comment: "Hashcat workload profile (e.g. 1 for low, 2 for medium, 3 for high, 4 for insane)"
      t.boolean :disable_markov, null: false, default: false, comment: "Is Markov chain disabled?"
      t.boolean :classic_markov, null: false, default: false, comment: "Is classic Markov chain enabled?"
      t.integer :markov_threshold, null: true, default: 0, comment: "Hashcat Markov threshold (e.g. 1000)"

      t.string :type

      t.string :left_rule, null: true, default: "", comment: "Left rule"
      t.string :right_rule, null: true, default: "", comment: "Right rule"
      t.string :custom_charset_1, null: true, default: "", comment: "Custom charset 1"
      t.string :custom_charset_2, null: true, default: "", comment: "Custom charset 2"
      t.string :custom_charset_3, null: true, default: "", comment: "Custom charset 3"
      t.string :custom_charset_4, null: true, default: "", comment: "Custom charset 4"
    end
  end
end
