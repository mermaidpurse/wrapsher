# frozen_string_literal: true

require 'rubygems'

module Wrapsher
  # Define default include path
  class Include
    class << self
      def calculate_gem_path
        gem_root = Gem::Specification.find_by_path(__FILE__)&.gem_dir
        gem_root = File.expand_path('../..', __dir__) if gem_root.nil?
        File.join(gem_root, 'wsh')
      end

      def calculate_path
        (ENV['WSH_INCLUDE'] ? ENV['WSH_INCLUDE'].split(':') : []) + [calculate_gem_path]
      end

      def path
        @path ||= calculate_path
      end
    end
  end
end
