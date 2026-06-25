# frozen_string_literal: true

module Sasso
  module Rails
    # Versioned INDEPENDENTLY of both the `sasso` gem and the `sasso` crate.
    # The gemspec pins the engine gem with a range (sasso >= 0.1.1, < 1), so a
    # compiler bump does not force a lockstep release of this integration gem.
    VERSION = "0.1.5"
  end
end
