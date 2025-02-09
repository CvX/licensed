# frozen_string_literal: true
require "test_helper"
require "tmpdir"
require "fileutils"

if Licensed::Shell.tool_available?("gradle")
  describe Licensed::Sources::Gradle do
    describe "Single project" do
      let(:fixtures) { File.expand_path("../../fixtures/gradle/single_project", __FILE__) }
      let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd, "root" => fixtures }) }
      let(:source) { Licensed::Sources::Gradle.new(config) }

      describe "enabled?" do
        it "is true if build.gradle exists and gradle is available" do
          Dir.chdir(fixtures) do
            assert source.enabled?
          end
        end

        it "is false if build.gradle does not exist" do
          Dir.chdir(Dir.tmpdir) do
            refute source.enabled?
          end
        end
      end

      describe "dependencies" do
        it "includes declared dependencies" do
          Dir.chdir fixtures do
            dep = source.dependencies.detect { |d| d.name == "io.netty:netty-all" }
            assert dep
            assert_equal "gradle", dep.record["type"]
            assert_equal "4.1.33.Final", dep.version
          end
        end

        it "does not include test dependencies" do
          Dir.chdir fixtures do
            refute source.dependencies.detect { |d| d.name == "org.junit.jupiter:junit-jupiter" }
          end
        end

        it "cleans up grade licenses csv content" do
          Dir.chdir fixtures do
            dep = source.dependencies.detect { |d| d.name == "io.netty:netty-all" }
            # load the dependency record which creates temp license-*.gradle files
            dep.record

            refute Dir.glob(Pathname.pwd.join("license-*.gradle").to_path).any?
          end
        end
      end
    end

    describe "Multi project" do
      let(:fixtures) { File.expand_path("../../fixtures/gradle/multi_project", __FILE__) }
      let(:config) { Licensed::Configuration.new({
        "apps" => [{ "source_path" => "#{Dir.pwd}/lib" }, { "source_path" => "#{Dir.pwd}/app" }],
        "gradle" => { "configurations" => "runtimeClasspath" },
        "root" => fixtures
      })
      }
      let(:appConfig) { config.apps.last }
      let(:libConfig) { config.apps.last }
      let(:source) { Licensed::Sources::Gradle.new(appConfig) }

      describe "app subproject" do
        let(:appConfig) { config.apps.last }
        let(:source) { Licensed::Sources::Gradle.new(appConfig) }

        describe "enabled?" do
          it "is true if build.gradle exists and gradle is available" do
            Dir.chdir(fixtures) do
              assert source.enabled?
            end
          end

          it "is false if build.gradle does not exist" do
            Dir.chdir(Dir.tmpdir) do
              refute source.enabled?
            end
          end
        end

        describe "dependencies" do
          it "includes declared dependencies" do
            Dir.chdir fixtures do
              dep = source.dependencies.detect { |d| d.name == "com.google.guava:guava" }
              assert dep
              assert_equal "gradle", dep.record["type"]
              assert_equal "31.1-jre", dep.version
            end
          end

          it "does not include test dependencies" do
            Dir.chdir fixtures do
              refute source.dependencies.detect { |d| d.name == "org.junit.jupiter:junit-jupiter-engine" }
            end
          end

          it "cleans up grade licenses csv content" do
            Dir.chdir fixtures do
              dep = source.dependencies.detect { |d| d.name == "com.google.guava:guava" }
              # load the dependency record which creates temp license-*.gradle files
              dep.record

              refute Dir.glob(Pathname.pwd.join("license-*.gradle").to_path).any?
            end
          end
        end
      end

      describe "lib subproject" do
        let(:appConfig) { config.apps.first }
        let(:source) { Licensed::Sources::Gradle.new(appConfig) }
        describe "enabled?" do
          it "is true if build.gradle exists and gradle is available" do
            Dir.chdir(fixtures) do
              assert source.enabled?
            end
          end

          it "is false if build.gradle does not exist" do
            Dir.chdir(Dir.tmpdir) do
              refute source.enabled?
            end
          end
        end

        describe "dependencies" do
          it "includes declared dependencies" do
            Dir.chdir fixtures do
              dep = source.dependencies.detect { |d| d.name == "com.google.guava:guava" }
              assert dep
              assert_equal "gradle", dep.record["type"]
              assert_equal "31.1-jre", dep.version
            end
          end

          it "does not include test dependencies" do
            Dir.chdir fixtures do
              refute source.dependencies.detect { |d| d.name == "org.junit.jupiter:junit-jupiter-engine" }
            end
          end

          it "cleans up grade licenses csv content" do
            Dir.chdir fixtures do
              dep = source.dependencies.detect { |d| d.name == "com.google.guava:guava" }
              # load the dependency record which creates temp license-*.gradle files
              dep.record

              refute Dir.glob(Pathname.pwd.join("license-*.gradle").to_path).any?
            end
          end
        end
      end
    end
  end

  describe Licensed::Sources::Gradle::Dependency do
    let(:fixtures) { File.expand_path("../../fixtures/gradle/single_project", __FILE__) }
    let(:config) { Licensed::AppConfiguration.new({ "source_path" => Dir.pwd, "root" => fixtures }) }
    let(:source) { Licensed::Sources::Gradle.new(config) }

    it "returns the dependency license" do
      Dir.chdir fixtures do
        dep = source.dependencies.detect { |d| d.name == "io.netty:netty-all" }
        assert dep
        assert_equal "apache-2.0", dep.license.key

        license = dep.record.licenses.find { |l| l.text =~ /Apache License/ }
        assert license
        assert_equal ["https://www.apache.org/licenses/LICENSE-2.0"], license.sources
      end
    end

    it "cleans up grade licenses csv content" do
      Dir.chdir fixtures do
        dep = source.dependencies.detect { |d| d.name == "io.netty:netty-all" }
        # load the dependency record, pulling license files
        dep.record

        refute Pathname.pwd.join(Licensed::Sources::Gradle::GRADLE_LICENSES_PATH).exist?
      end
    end

    it "does not make any network requests when accessing non-license data" do
      Licensed::Sources::Gradle::Dependency.expects(:retrieve_license).never
      Licensed::Sources::Gradle::Dependency.expects(:load_csv).never

      Dir.chdir fixtures do
        dep = source.dependencies.detect { |d| d.name == "io.netty:netty-all" }
        # accessing non-license dependency data does not make network requests
        dep.name
        dep.version
      end
    end
  end
end
