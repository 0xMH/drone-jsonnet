local notfications() = {
  kind: 'pipeline',
  type: 'kubernetes',
  name: 'notify-pipeline-start',
  steps: [
    {
      name: 'notify-start',
      image: 'plugins/slack',
      settings: {
        channel: 'drone-notifications',
        webhook: {
          from_secret: 'slack_webhook_url',
        },
        template: '{{#if build.pull }}\n  *Build started*: {{ repo.owner }}/{{ repo.name }} - <https://github.com/{{ repo.owner }}/{{ repo.name }}/pull/{{ build.pull }}|Pull Request #{{ build.pull }}>\n{{else}}\n  *Build started: {{ repo.owner }}/{{ repo.name }} - Build #{{ build.number }}* (type: `{{ build.event }}`)\n{{/if}} Commit: <https://github.com/{{ repo.owner }}/{{ repo.name }}/commit/{{ build.commit }}|{{ truncate build.commit 8 }}> Branch: <https://github.com/{{ repo.owner }}/{{ repo.name }}/commits/{{ build.branch }}|{{ build.branch }}> Author: {{ build.author }} <{{ build.link }}|Visit build page ↗>\n',
      },
      when: {
        branch: [
          'master',
          'dev',
          'staging',
          'test',
          'demo',
          'prod',
          'einshams-v2',
        ],
        event: [
          'push',
        ],
      },
    },
  ],
};


local publishToEcr(ServiceName) = {
  name: 'publishToEcr',
  image: 'plugins/ecr',
  settings: {
    dockerfile: ServiceName + '/Dockerfile',
    mirror: 'http://34.229.17.151:7000',
    access_key: {
      from_secret: 'aws_access_key_id',
    },
    secret_key: {
      from_secret: 'aws_secret_access_key',
    },
    repo: 'drone-test/' + ServiceName,
    registry: '624792314775.dkr.ecr.us-east-1.amazonaws.com',
    region: 'us-east-1',
    tags: [
      '${DRONE_COMMIT_SHA:0:8}',
      '${DRONE_BRANCH}',
    ],
  },
};
local deployT0K8s(ServiceName) = {
  name: 'deployT0K8s',
  image: 'quay.io/honestbee/drone-kubernetes',
  settings: {
    KUBERNETES_SERVER: {
      from_secret: 'kubernetes_server',
    },
    KUBERNETES_TOKEN: {
      from_secret: 'kubernetes_token',
    },
    KUBERNETES_CERT: {
      from_secret: 'kubernetes_cert',
    },
    namespace: 'dronetest',
    deployment: ServiceName,
    repo: '624792314775.dkr.ecr.us-east-1.amazonaws.com/drone-test/' + ServiceName,
    container: ServiceName,
    tag: '${DRONE_COMMIT_SHA:0:8}',
  },
};

local commitToNonMasterSteps = [
  publishToEcr('service1'),
  deployT0K8s('service1'),
];


local unitTestPipeline(ServiceName) = {
  kind: 'pipeline',
  type: 'kubernetes',
  name: ServiceName,
  steps: [
    {
      name: 'unit-test',
      image: 'golang:1.14',
      commands: [
        'cd ' + ServiceName,
        'go build',
        'go test',
      ],
    },
  ],
};

local Pipeline(RepoName, ServiceName) = {
  kind: 'pipeline',
  type: 'kubernetes',
  name: ServiceName + '-deploy',
  steps: [
    {
      name: 'publishToEcr',
      image: 'plugins/ecr',
      settings: {
        dockerfile: ServiceName + '/Dockerfile',
        mirror: 'http://34.229.17.151:7000',
        access_key: {
          from_secret: 'aws_access_key_id',
        },
        secret_key: {
          from_secret: 'aws_secret_access_key',
        },
        repo: RepoName + '/' + ServiceName,
        registry: '624792314775.dkr.ecr.us-east-1.amazonaws.com',
        region: 'us-east-1',
        tags: [
          '${DRONE_COMMIT_SHA:0:8}',
          '${DRONE_BRANCH}',
        ],
      },
      when: {
        branch: [
          'dev',
          'test',
          'demo',
          'staging',
          'prod',
          'einshams-v2',
        ],
        event: [
          'push',
          'custom',
        ],
      },


    },
    {
      name: 'deployT0K8s',
      image: 'quay.io/honestbee/drone-kubernetes',
      settings: {
        KUBERNETES_SERVER: {
          from_secret: 'kubernetes_server',
        },
        KUBERNETES_TOKEN: {
          from_secret: 'kubernetes_token',
        },
        KUBERNETES_CERT: {
          from_secret: 'kubernetes_cert',
        },
        namespace: 'dronetest',
        deployment: ServiceName,
        repo: '624792314775.dkr.ecr.us-east-1.amazonaws.com/' + RepoName + '/' + ServiceName,
        container: ServiceName,
        tag: '${DRONE_COMMIT_SHA:0:8}',
      },
      when: {
        branch: [
          'dev',
          'test',
          'demo',
          'staging',
        ],
        event: [
          'custom',
          'push',
        ],
      },
    },
  ],
};


local MultiBranchTrigger(step) = step {
  trigger: {
    branch: [
      'master',
      'dev',
      'staging',
      'test',
      'demo',
      'prod',
      'einshams-v2',
    ],
  },
};


local ServicesDependencies(step, Dependencies) = step {
  depends_on: Dependencies,
};


local whenCommitToMaster(step) = step {
  trigger: {
    branch: [
      'main',
    ],
  },
};

local pipelines = std.flattenArrays([
  commitToNonMasterSteps,
]);


local finechServices = ['service-balance', 'bff-raseedy'];

// local final_meal = [
//   { name: 'food_' + type, value: 'like' }
//   for type in food_type
// ];

local finalPipelines = [
  ServicesDependencies(Pipeline('fintech', Service), finechServices)
  for Service in finechServices
];


// notfications(),
// whenCommitToMaster(Pipeline('service1')),
// Pipeline('service2'),
// MultiBranchTrigger(unitTestPipeline('unittest11111')),
finalPipelines
// Below is the actual JSON object that will be emitted by the jsonnet compiler.



