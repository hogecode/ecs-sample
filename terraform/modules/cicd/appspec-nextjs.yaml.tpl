version: 0.0

Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "<TASK_DEFINITION>"
        LoadBalancerInfo:
          ContainerName: "${container_name}"
          ContainerPort: ${container_port}

Hooks:
  - BeforeAllowTraffic: "CodeDeployHook_BeforeAllowTraffic"
  - AfterAllowTraffic: "CodeDeployHook_AfterAllowTraffic"
