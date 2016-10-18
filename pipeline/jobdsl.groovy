import org.yaml.snakeyaml.*

def envPath = 'environment'
def orchPath = 'orchestrator'
def orchJob = "${JOB_NAME}"
def workspace = "${WORKSPACE}"

def yaml = new Yaml();
def manifest = new File("$workspace/$envPath/manifest.yml").getText()
def map = (Map) yaml.load(manifest);
def stackEnv = map.env_name

//iterate through the tech stacks in the manifest
map.tech_stacks.each { stackNode ->

    def stackName = (String)stackNode.getKey()
    def stackInfo = (Map)stackNode.getValue()
    def stackPath = orchPath + '/tech_stacks/' + stackName
    def stackUrl = stackInfo.url
    def branch = stackInfo.branch

  	//construct the shell commands
    def rsyncCmd = "rsync -av --exclude=$orchPath ./ ./orchestrator/tech_stacks/$stackName"
    def sudoCmd = '''sudo AWS_REGION=${awsRegionParam} DOCKER_BUCKET_NAME=${dockerBucketName} ORCHESTRATOR_NAME=${orchestratorName} /bin/bash -l <<"EOF"
set -ex
'''
    def permCmd = "sudo chmod -R 755 $orchPath"
    def runCmd = "(cd $orchPath && ./run_stack.sh $stackName $stackEnv)"
    def chownCmd = "(cd $orchPath/tech_stacks/$stackName && chown -R jenkins:jenkins test dist)"
    def eofCloseCmd = 'EOF'

    def destroyCmd = "(cd $orchPath && echo Y | ./destroy_stack.sh" +' "${ORCHESTRATOR_NAME}" ' + "$stackEnv $stackName)"

    def systemUuidFile = new File('/var/lib/system_uuid')
    if(!systemUuidFile.exists()) {
      throw new RuntimeException('The file /var/lib/system_uuid must exist and contain output of dmidecode --system-uuid')
    }
    def persistentMachineId = systemUuidFile.text.trim().collect { it ->
      if(Character.isLetter((char)it)) {
        return Character.toLowerCase((char)it);
      }
      else {
        return (char)(Character.getNumericValue((char)it)+97);
      }
    }.join('').replace('-','')

    //create a folder for the tech stack and env
  	folder "$stackName"
    folder "$stackName/$stackEnv"

    //create the pipeline jobs for the tech stack env
    job("$stackName/$stackEnv/runStack") {
        parameters {
          stringParam('awsRegionParam', 'us-east-1', 'AWS Region')
          stringParam('orchestratorName', persistentMachineId.take(8), '')
          stringParam('dockerBucketName', 'orchestrator-resources', '')

        }

        scm {
            git(stackUrl, branch){ node ->
               node / gitConfigName('GCB Orchestrator')
               node / gitConfigEmail('gcb.orchestrator@citi.com')
               node.extensions[0].appendNode('hudson.plugins.git.extensions.impl.CleanBeforeCheckout')
            }
        }

        triggers {
            scm 'H/30 * * * *'
        }

        steps {
          copyArtifacts(orchJob.toString()) {
            includePatterns(orchPath + '/**/*')
            excludePatterns()
            targetDirectory()
            flatten(false)
            optional(false)
            fingerprintArtifacts(false)
            parameterFilters()
            buildSelector {
                latestSuccessful(true)
            }
          }
          copyArtifacts(orchJob.toString()) {
              includePatterns(envPath + '/manifest.yml')
              excludePatterns()
              targetDirectory(stackPath)
              flatten(false)
              optional(false)
              fingerprintArtifacts(false)
              parameterFilters()
              buildSelector {
                  latestSuccessful(true)
              }
            }
          shell """
#!/binb/bash -l
${rsyncCmd}
${sudoCmd}
${permCmd}
${runCmd}
${chownCmd}
${eofCloseCmd}
"""
        }
    }

    job("$stackName/$stackEnv/destroyStack") {
        parameters {
          stringParam('awsRegionParam', 'us-east-1', 'AWS Region')
          stringParam('orchestratorName', persistentMachineId.take(8), '')
          stringParam('dockerBucketName', 'orchestrator-resources', '')

        }

        scm {
            git(stackUrl, branch){ node ->
               node / gitConfigName('GCB Orchestrator')
               node / gitConfigEmail('gcb.orchestrator@citi.com')
               node.extensions[0].appendNode('hudson.plugins.git.extensions.impl.CleanBeforeCheckout')
            }
        }

        steps {
          copyArtifacts(orchJob.toString()) {
            includePatterns(orchPath + '/**/*')
            excludePatterns()
            targetDirectory()
            flatten(false)
            optional(false)
            fingerprintArtifacts(false)
            parameterFilters()
            buildSelector {
                latestSuccessful(true)
            }
          }
          copyArtifacts(orchJob.toString()) {
              includePatterns(envPath + '/manifest.yml')
              excludePatterns()
              targetDirectory(stackPath)
              flatten(false)
              optional(false)
              fingerprintArtifacts(false)
              parameterFilters()
              buildSelector {
                  latestSuccessful(true)
              }
            }
          shell """
#!/binb/bash -l
${rsyncCmd}
${sudoCmd}
${permCmd}
${destroyCmd}
${eofCloseCmd}
"""
        }
    }
}
