# config.ru
# ENV['RACK_ENV'] ||= 'development'
# require 'bundler/setup'
# Bundler.require(:default, ENV['RACK_ENV'].to_sym)
# require_relative './app'
# run Wordgym
ENV['RACK_ENV'] ||= ENV['APP_ENV'] || 'production'

require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'].to_sym)

require_relative "./app"
run Wordgym