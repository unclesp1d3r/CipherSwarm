# frozen_string_literal: true

json.array! @attacks, partial: "attacks/attack", as: :attack
