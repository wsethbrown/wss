# Shared value normalization for ghost-edit proposals: what gets STORED as
# proposed_value (so identical submissions group together for auto-apply)
# and what gets WRITTEN onto the bottle column when a proposal is applied.
# abv is the only field needing numeric normalization, the other four
# whitelisted fields are strings compared as-is (no case-folding: "Buffalo
# Trace" and "buffalo trace" are different proposals, matching how the
# model layer treats them as different values).
module BottleEdits
  class Normalize
    # String → String, safe to store as BottleEdit#proposed_value.
    def self.for_storage(field, raw_value)
      value = raw_value.to_s.strip
      return value unless field == "abv"

      begin
        format("%.1f", BigDecimal(value))
      rescue ArgumentError, TypeError
        value # invalid numeric text is stored as-is; Bottle's own
        # numericality validation catches it if/when it's ever applied
      end
    end

    # String → the type Bottle#<field>= expects (BigDecimal for abv, String
    # otherwise).
    def self.for_write(field, stored_value)
      return stored_value unless field == "abv"

      BigDecimal(stored_value)
    rescue ArgumentError, TypeError
      stored_value
    end
  end
end
