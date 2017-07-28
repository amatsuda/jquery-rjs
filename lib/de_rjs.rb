require 'rails'
require 'active_support'

unless defined? JQUERY_VAR
  JQUERY_VAR = 'jQuery'
end

module DeRjs
end

require 'de_rjs/jquery_generator'
require 'de_rjs/rewriter'
