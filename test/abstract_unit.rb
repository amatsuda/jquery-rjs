lib = File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

$:.unshift(File.dirname(__FILE__) + '/lib')

require 'rubygems'
require 'bundler/setup'
require "minitest/autorun"
require 'active_support'
require 'action_controller'
require 'action_view'

require 'de_rjs'
