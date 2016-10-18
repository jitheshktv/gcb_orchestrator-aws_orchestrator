@orchestrator
Feature: Jenkins.....
  As a DevOps user,
  I want to develop .....
  So I can ....

  Scenario: Stack CI
    Given a tech stack exists (in some registry?)
     When Jenkins job seed runs
     Then a job is created to do CI for each tech stack
      And the job has the name of the tech stack