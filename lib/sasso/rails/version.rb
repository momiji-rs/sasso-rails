# frozen_string_literal: true

module Sasso
  module Rails
    # Versioned INDEPENDENTLY of both the `sasso` gem and the `sasso` crate: the
    # gemspec depends on a RANGE of the engine gem, so a compiler bump does not
    # force a lockstep release of this integration gem. The range itself lives in
    # the gemspec and is deliberately not restated here — this comment claimed
    # `>= 0.1.1` through two floor bumps. `Sasso::CORE_VERSION` reports the
    # compiler actually installed.
    VERSION = "0.1.7"
  end
end
