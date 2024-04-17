import {Controller} from "@hotwired/stimulus"

// Connects to data-controller="attack"
export default class extends Controller {
  connect() {
    console.log("Connected to attack controller")
    this.#set_fieldset_visibility();
  }

  attack_mode(event) {
    let selected_mode = event.target.value;
    this.#set_fieldset_visibility(selected_mode);
  }

  #set_fieldset_visibility(selected_mode = "dictionary") {
    let dictionary_set = document.querySelector("fieldset#dictionary_attack_set")
    let combinator_set = document.querySelector("fieldset#combination_attack_set")
    let mask_set = document.querySelector("fieldset#mask_attack_set")
    let incremental_set = document.querySelector("fieldset#incremental_attack_set")
    let character_set = document.querySelector("fieldset#character_sets_attack_set")
    let markov_set = document.querySelector("fieldset#markov_attack_set")

    switch (selected_mode) {
      case "dictionary":
        dictionary_set.removeAttribute("hidden");
        combinator_set.setAttribute("hidden", "hidden");
        mask_set.setAttribute("hidden", "hidden");
        incremental_set.setAttribute("hidden", "hidden");
        character_set.setAttribute("hidden", "hidden");
        markov_set.setAttribute("hidden", "hidden");
        break;
      case "combinator":
        dictionary_set.removeAttribute("hidden");
        combinator_set.removeAttribute("hidden");
        mask_set.setAttribute("hidden", "hidden");
        incremental_set.setAttribute("hidden", "hidden");
        character_set.setAttribute("hidden", "hidden");
        markov_set.setAttribute("hidden", "hidden");
        break;
      case "mask":
        dictionary_set.setAttribute("hidden", "hidden");
        combinator_set.setAttribute("hidden", "hidden");
        mask_set.removeAttribute("hidden");
        incremental_set.removeAttribute("hidden");
        character_set.removeAttribute("hidden");
        markov_set.setAttribute("hidden", "hidden");
        break;
      case "hybrid_dictionary":
      case "hybrid_mask":
        dictionary_set.removeAttribute("hidden");
        combinator_set.setAttribute("hidden", "hidden");
        mask_set.removeAttribute("hidden");
        incremental_set.setAttribute("hidden", "hidden");
        character_set.setAttribute("hidden", "hidden");
        markov_set.setAttribute("hidden", "hidden");
        break;
      default:
        dictionary_set.removeAttribute("hidden");
        combinator_set.setAttribute("hidden", "hidden");
        mask_set.removeAttribute("hidden");
        incremental_set.setAttribute("hidden", "hidden");
        character_set.setAttribute("hidden", "hidden");
        markov_set.setAttribute("hidden", "hidden");
    }
  }
}
