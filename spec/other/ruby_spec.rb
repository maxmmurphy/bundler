require "spec_helper"

describe "bundle ruby" do
  it "returns ruby version when explicit" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      ruby_version "1.9.3", :engine => 'ruby', :engine_version => '1.9.3'

      gem "foo"
    G

    bundle "ruby"

    out.should eq("ruby 1.9.3 (ruby 1.9.3)")
  end

  it "engine defaults to MRI" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      ruby_version "1.9.3"

      gem "foo"
    G

    bundle "ruby"

    out.should eq("ruby 1.9.3 (ruby 1.9.3)")
  end

  it "handles jruby" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      ruby_version "1.8.7", :engine => 'jruby', :engine_version => '1.6.5'

      gem "foo"
    G

    bundle "ruby"

    out.should eq("ruby 1.8.7 (jruby 1.6.5)")
  end

  it "handles rbx" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      ruby_version "1.8.7", :engine => 'rbx', :engine_version => '1.2.4'

      gem "foo"
    G

    bundle "ruby"

    out.should eq("ruby 1.8.7 (rbx 1.2.4)")
  end

  it "raises an error if engine is used but engine version is not" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      ruby_version "1.8.7", :engine => 'rbx'

      gem "foo"
    G

    bundle "ruby", :exitstatus => true

    exitstatus.should_not == 0
  end

  it "raises an error if engine_version is used but engine is not" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      ruby_version "1.8.7", :engine_version => '1.2.4'

      gem "foo"
    G

    bundle "ruby", :exitstatus => true

    exitstatus.should_not == 0
  end

  it "raises an error if engine version doesn't match ruby version for mri" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      ruby_version "1.8.7", :engine => 'ruby', :engine_version => '1.2.4'

      gem "foo"
    G

    bundle "ruby", :exitstatus => true

    exitstatus.should_not == 0
  end

  let(:ruby_version_correct) { "ruby_version \"#{RUBY_VERSION}\", :engine => \"#{local_ruby_engine}\", :engine_version => \"#{local_engine_version}\"" }
  let(:ruby_version_incorrect) { "ruby_version \"#{not_local_ruby_version}\", :engine => \"#{local_ruby_engine}\", :engine_version => \"#{not_local_ruby_version}\"" }
  let(:engine_incorrect) { "ruby_version \"#{RUBY_VERSION}\", :engine => \"#{not_local_tag}\", :engine_version => \"#{RUBY_VERSION}\"" }
  let(:engine_version_incorrect) { "ruby_version \"#{RUBY_VERSION}\", :engine => \"#{local_ruby_engine}\", :engine_version => \"#{not_local_engine_version}\"" }

  def should_be_ruby_version_incorrect
    exitstatus.should eq(18)
    out.should == "Your Ruby version is #{RUBY_VERSION}, but your Gemfile specified #{not_local_ruby_version}"
  end

  def should_be_engine_incorrect
    exitstatus.should eq(18)
    out.should == "Your Ruby engine is #{local_ruby_engine}, but your Gemfile specified #{not_local_tag}"
  end

  def should_be_engine_version_incorrect
    exitstatus.should eq(18)
    out.should == "Your #{local_ruby_engine} version is #{local_engine_version}, but your Gemfile specified #{local_ruby_engine} #{not_local_engine_version}"
  end

  context "bundle install" do
    it "installs fine when the ruby version matches" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"

        #{ruby_version_correct}
      G

      bundled_app('Gemfile.lock').should exist
    end

    it "doesn't install when the ruby version doesn't match" do
      install_gemfile <<-G, :exitstatus => true
        source "file://#{gem_repo1}"
        gem "rack"

        #{ruby_version_incorrect}
      G

      bundled_app('Gemfile.lock').should_not exist
      should_be_ruby_version_incorrect
    end

    it "doesn't install when engine doesn't match" do
      install_gemfile <<-G, :exitstatus => true
        source "file://#{gem_repo1}"
        gem "rack"

        #{engine_incorrect}
      G

      bundled_app('Gemfile.lock').should_not exist
      should_be_engine_incorrect
    end

    it "doesn't install when engine version doesn't match" do
      simulate_ruby_engine "jruby" do
        install_gemfile <<-G, :exitstatus => true
          source "file://#{gem_repo1}"
          gem "rack"

          #{engine_version_incorrect}
        G

        bundled_app('Gemfile.lock').should_not exist
        should_be_engine_version_incorrect
      end
    end
  end

  context "bundle check" do
    it "checks fine when the ruby version matches" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"

        #{ruby_version_correct}
      G

      bundle :check, :exitstatus => true
      exitstatus.should eq(0)
      out.should == "The Gemfile's dependencies are satisfied"
    end

    it "fails when ruby version doesn't match" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"

        #{ruby_version_incorrect}
      G

      bundle :check, :exitstatus => true
      should_be_ruby_version_incorrect
    end

    it "fails when engine doesn't match" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"

        #{engine_incorrect}
      G

      bundle :check, :exitstatus => true
      should_be_engine_incorrect
    end

    it "fails when engine version doesn't match" do
      simulate_ruby_engine "ruby" do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
        G

        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"

          #{engine_version_incorrect}
        G

        bundle :check, :exitstatus => true
        should_be_engine_version_incorrect
      end
    end
  end

  context "bundle update" do
    before do
      build_repo2

      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "activesupport"
        gem "rack-obama"
      G
    end

    it "updates successfully when the ruby version matches" do
      gemfile <<-G
        source "file://#{gem_repo2}"
        gem "activesupport"
        gem "rack-obama"

        #{ruby_version_correct}
      G
      update_repo2 do
        build_gem "activesupport", "3.0"
      end

      bundle "update"
      should_be_installed "rack 1.2", "rack-obama 1.0", "activesupport 3.0"
    end

    it "fails when ruby version doesn't match" do
      gemfile <<-G
        source "file://#{gem_repo2}"
        gem "activesupport"
        gem "rack-obama"

        #{ruby_version_incorrect}
      G
      update_repo2 do
        build_gem "activesupport", "3.0"
      end

      bundle :update, :exitstatus => true
      should_be_ruby_version_incorrect
    end

    it "fails when ruby engine doesn't match" do
      gemfile <<-G
        source "file://#{gem_repo2}"
        gem "activesupport"
        gem "rack-obama"

        #{engine_incorrect}
      G
      update_repo2 do
        build_gem "activesupport", "3.0"
      end

      bundle :update, :exitstatus => true
      should_be_engine_incorrect
    end

    it "fails when ruby engine version doesn't match" do
      simulate_ruby_engine "jruby" do
        gemfile <<-G
          source "file://#{gem_repo2}"
          gem "activesupport"
          gem "rack-obama"

          #{engine_version_incorrect}
        G
        update_repo2 do
          build_gem "activesupport", "3.0"
        end

        bundle :update, :exitstatus => true
        should_be_engine_version_incorrect
      end
    end
  end

  context "bundle show" do
    before do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"
      G
    end

    it "prints path if ruby version is correct" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"

        #{ruby_version_correct}
      G

      bundle "show rails"
      out.should == default_bundle_path('gems', 'rails-2.3.2').to_s
    end

    it "fails if ruby version doesn't match" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"

        #{ruby_version_incorrect}
      G

      bundle "show rails", :exitstatus => true
      should_be_ruby_version_incorrect
    end

    it "fails if engine doesn't match" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"

        #{engine_incorrect}
      G

      bundle "show rails", :exitstatus => true
      should_be_engine_incorrect
    end

    it "fails if engine version doesn't match" do
      simulate_ruby_engine "jruby" do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rails"

          #{engine_version_incorrect}
        G

        bundle "show rails", :exitstatus => true
        should_be_engine_version_incorrect
      end
    end
  end
end
