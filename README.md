# Logstash Plugin

[![Build Status](https://travis-ci.org/ChronixDB/chronix.logstash.svg?branch=master)](https://travis-ci.org/ChronixDB/chronix.logstash)

This is a plugin for [Logstash](https://github.com/elastic/logstash) to write time series to Chronix released under the Apache 2.0 license.

## Install the plugin

There are two options to install the plugin. (check one the official [Logstash Repos](https://github.com/logstash-plugins/logstash-output-example#2-running-your-unpublished-plugin-in-logstash) for reference.

### Install in a local Logstash Clone:
- Edit Logstash `Gemfile` and add the local plugin path, for example:
```ruby
gem "logstash-output-chronix", :path => "/path/to/logstash-output-chronix"
```
- Install plugin
```sh
bin/plugin install --no-verify
```
- Run Logstash with a config for the plugin (see the Configuration section for help)
```sh
bin/logstash -e your_config.conf
```

### Run in an installed Logstash

You can use the same method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory or you can build the gem and install it using:

- Build your plugin gem
```sh
gem build logstash-output-chronix.gemspec
```
- Install the plugin from the Logstash home
```sh
bin/plugin install /path/to/logstash/plugin/logstash-output-chronix.gem
```
- Start Logstash and proceed to test the plugin


## Configuration

Chronix always needs a 'metric' to store your data. During the filter-phase you should at least add a metric-field to your data.
Example:
```
filter {
  mutate { add_field => { "metric" => "your_metric" } }
}
```

You also have to add Chronix to your output. You can add some custom values to configure the plugin.
Here is an example with all the configuration options:
```
chronix {
  host => "192.168.0.1"		# default is 'localhost'
  port => "8983"		# default is '8983'
  path => "/solr/chronix/"	# default is '/solr/chronix/'
  flush_size => 100		# default is '100' (Number of events to queue up before writing to Solr)
  idle_flush_time => 30		# default is '30'  (Amount of time since the last flush before a flush is done)
}
```

