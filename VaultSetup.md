# Centralized Test Execution & Secure Test Data Management Platform

**Document Type:** Solution Architecture & Technical Implementation Guide\
**Status:** Proposed Architecture / Implementation Blueprint\
**Technology Stack:** GitHub Actions, GitHub Reusable Workflows, HashiCorp Vault, GitHub OIDC, Java, Maven, Selenium, Cucumber\
**Audience:** SDET Engineers, Automation Architects, DevOps Engineers, Platform Engineering, Security and Engineering Leadership

---

# 1. Executive Summary

This initiative proposes a centralized test execution and secure test data management platform to standardize automation execution across multiple application repositories.

The solution introduces a centralized orchestration repository that dispatches smoke and regression test executions across participating automation repositories.

A centrally maintained reusable GitHub Actions workflow manages the common execution lifecycle, including:

- Repository-specific configuration discovery.
- Secure authentication with HashiCorp Vault using GitHub OIDC.
- Retrieval of authorized test data and credentials.
- Dynamic delivery of test data through environment variables or runtime files.
- Maven-based automation execution.
- Parallel test execution.
- Runtime cleanup.
- Execution result collection and reporting.

Each application repository maintains its own `Secret-manifest.yaml`, defining its test-data requirements and preferred delivery mechanism.

The reusable workflow interprets this manifest and delivers the requested data without requiring repository-specific implementation logic.

**Core architectural principle:**

Centralize implementation, decentralize configuration, enforce security at the platform boundary.

# 2. Business Objectives

The platform is intended to address the following engineering challenges:

| Current challenge                                        | Proposed solution                          |
| -------------------------------------------------------- | ------------------------------------------ |
| Duplicated GitHub Actions implementations                | Centrally maintained reusable workflows    |
| Inconsistent test-data management                        | Standardized manifest-driven configuration |
| Credentials stored in repository files or GitHub secrets | HashiCorp Vault integration                |
| Manual test-data preparation                             | Automated runtime data delivery            |
| Different execution implementations across repositories  | Common execution contract                  |
| Fragmented execution visibility                          | Centralized reporting                      |
| Increasing regression execution time                     | Parallel execution support                 |
| High maintenance effort                                  | Configuration-driven onboarding            |

## Expected business benefits

1. Reduced duplication of workflow implementations.
2. Improved security governance and auditability.
3. Faster feedback through parallel test execution.
4. Consistent execution standards across repositories.
5. Faster onboarding of new automation projects.
6. Improved visibility into automation health and execution failures.

Benefits and savings should be measured during the pilot rather than assumed.

# 3. High-Level Architecture

The architecture consists of six logical components.

1. Central Orchestration Layer
2. Repository Configuration Layer
3. Identity and Security Layer
4. Secret Provider and Data Delivery Layer
5. Test Execution Layer
6. Observability and Reporting Layer

## 3.1 Architecture Diagram

```
flowchart TD
    A[Centralized Orchestration Repository]

    A --> B[Dispatch Smoke / Regression]
    B --> C[Application Repository A]
    B --> D[Application Repository B]
    B --> E[Application Repository C]

    C --> F[Central Reusable Workflow]
    D --> F
    E --> F

    F --> G[Checkout Caller Repository]
    G --> H[Read Secret-manifest.yaml]
    H --> I[Validate Manifest]

    I --> J[GitHub OIDC Authentication]
    J --> K[HashiCorp Vault]

    K --> L[Retrieve Authorized Test Data]
    L --> M[Data Delivery Engine]

    M --> N[Environment Variables]
    M --> O[Runtime JSON / Properties Files]

    N --> P[Maven Test Execution]
    O --> P

    P --> Q[Parallel Test Execution]
    Q --> R[Execution Reports]

    R --> S[Centralized Reporting]
    S --> T[Dashboard and Analytics]
```

## 3.2 Component Responsibilities

| Component              | Responsibility                                            |
| ---------------------- | --------------------------------------------------------- |
| Orchestrator           | Dispatches execution across repositories                  |
| Application repository | Owns application-specific test configuration and manifest |
| Reusable workflow      | Implements common execution lifecycle                     |
| Manifest validator     | Validates schema, keys and delivery instructions          |
| Vault adapter          | Authenticates and retrieves authorized values             |
| Data delivery engine   | Creates ENV variables or runtime files                    |
| Maven execution        | Runs smoke and regression suites                          |
| Reporting component    | Aggregates execution results                              |

The components should remain independently maintainable.

# 4. Repository Structure

## 4.1 Centralized Orchestration Repository

```
Central-Automation/
│
├── .github/
│   └── workflows/
│       ├── orchestrator.yml
│       └── reusable-test-execution.yml
│
├── scripts/
│   ├── dispatch-repositories.sh
│   ├── validate-manifest.sh
│   ├── retrieve-vault-data.sh
│   ├── deliver-test-data.sh
│   ├── cleanup-runtime-data.sh
│   └── publish-results.sh
│
├── schemas/
│   └── secret-manifest-v1.schema.json
│
├── docs/
│   └── architecture.md
│
└── README.md
```

## 4.2 Application Repository

Each application repository maintains its own configuration.

```
Application-Repo/
│
├── .github/
│   ├── workflows/
│   │   └── smoke.yml
│   │
│   └── Secret-manifest.yaml
│
├── data/
│   └── test/
│       └── creds/
│
├── src/
│   └── test/
│
├── pom.xml
└── README.md
```

The `data/test/creds` directory contains runtime-generated files only. Sensitive runtime files must never be committed.

# 5. Central Orchestration Design

The orchestration repository is responsible for coordinating execution across application repositories.

It should not contain application-specific test-data logic or Vault retrieval implementation.

## 5.1 Execution Responsibilities

- Receive manual or scheduled dispatch requests.
- Identify participating repositories.
- Select smoke or regression execution.
- Select the target environment.
- Trigger the respective application workflows.
- Collect execution identifiers and results.
- Generate consolidated execution reporting.

## 5.2 Example Orchestrator Workflow

The following is a simplified implementation illustration. The repository list and authentication mechanism should be configured according to organizational governance.

```
name: Centralized Test Orchestrator

on:
  workflow_dispatch:
    inputs:
      test_type:
        description: Test suite
        type: choice
        options:
          - smoke
          - regression
        required: true

      environment:
        description: Execution environment
        type: choice
        options:
          - qa
          - preprod
        required: true

permissions:
  contents: read

jobs:
  dispatch:
    runs-on: ubuntu-latest

    strategy:
      fail-fast: false
      matrix:
        repository:
          - Repo-A
          - Repo-B
          - Repo-C

    steps:
      - name: Dispatch application workflow
        env:
          GH_TOKEN: ${{ secrets.CENTRAL_DISPATCH_TOKEN }}
          REPOSITORY: ${{ matrix.repository }}
          TEST_TYPE: ${{ inputs.test_type }}
          ENVIRONMENT: ${{ inputs.environment }}
        run: |
          gh workflow run smoke.yml \
            --repo YOUR-ORG/${REPOSITORY} \
            --ref main \
            -f test_type="${TEST_TYPE}" \
            -f environment="${ENVIRONMENT}"
```

**Important implementation considerations:**

- Use a GitHub App installation token with minimum repository and workflow permissions where possible.
- A PAT is an alternative, but should not be the default for a new enterprise implementation.
- `gh workflow run` dispatches execution; it does not itself wait for completion or aggregate results.
- Capture each dispatched run ID and implement a separate polling/result-collection stage.
- Use `fail-fast: false` so independent repository dispatches can continue after one failure.
- Avoid exposing the dispatch token in logs.

# 6. Application Repository Workflow

Each application repository invokes the centrally maintained reusable workflow.

The application workflow should remain lightweight.

## 6.1 Example Caller Workflow

File: `.github/workflows/smoke.yml`

```
name: Application Smoke Tests

on:
  workflow_dispatch:
    inputs:
      test_type:
        description: Test type
        required: true
        type: choice
        options:
          - smoke
          - regression

      environment:
        description: Target environment
        required: true
        type: choice
        options:
          - qa
          - preprod

permissions:
  contents: read
  id-token: write

jobs:
  execute-tests:
    uses: YOUR-ORG/Central-Automation/.github/workflows/reusable-test-execution.yml@v1.0.0

    with:
      test_type: ${{ inputs.test_type }}
      environment: ${{ inputs.environment }}

    permissions:
      contents: read
      id-token: write
```

Pin production workflow references to a verified immutable commit SHA. Version tags should be managed as controlled releases.

No application-specific Vault integration logic should be required in this caller workflow.

# 7. Manifest-Driven Test Data Management

Each application repository owns its own `Secret-manifest.yaml`.

The manifest defines:

- Vault key identifier.
- Data format.
- Delivery mechanism.
- Runtime destination when file delivery is selected.

The reusable workflow interprets the manifest dynamically.

## 7.1 Example Manifest

File: `.github/Secret-manifest.yaml`

```
schema_version: 1

secrets:
  - key: APP1_LOGIN
    type: JSON
    delivery:
      mode: FILE
      path: data/test/creds/login.json

  - key: APP1_PROPERTIES
    type: PROPERTIES
    delivery:
      mode: FILE
      path: data/test/creds/application.properties

  - key: APP1_PREPROD_DATA
    type: JSON
    delivery:
      mode: FILE
      path: data/test/creds/preprod.json

  - key: APP1_RUNTIME_CONFIG
    type: JSON
    delivery:
      mode: ENV
      variable: APP1_RUNTIME_CONFIG
```

## 7.2 Manifest Properties

| Property            | Description                    |
| ------------------- | ------------------------------ |
| `schema_version`    | Manifest schema version        |
| `key`               | Vault field identifier         |
| `type`              | JSON, PROPERTIES, YAML or TEXT |
| `delivery.mode`     | ENV or FILE                    |
| `delivery.path`     | Runtime file destination       |
| `delivery.variable` | Environment variable name      |

## 7.3 Manifest Validation Rules

The manifest validator must enforce:

1. Supported schema version.
2. Approved data types.
3. Supported delivery modes.
4. Required destination for FILE delivery.
5. Required variable name for ENV delivery.
6. No duplicate keys.
7. No duplicate destinations.
8. No absolute paths or path traversal.
9. Destination must remain within an approved runtime directory.
10. Requested Vault keys must be authorized for the calling repository.

The manifest must not be treated as a security authorization mechanism.

It declares requirements; Vault policies enforce authorization.

# 8. HashiCorp Vault Integration

HashiCorp Vault is the approved central secret and sensitive test-data store.

## 8.1 Recommended Vault Structure

Separate repository and environment boundaries.

```
secret/
│
├── qa/
│   ├── repo-a/
│   │   ├── APP1_LOGIN
│   │   ├── APP1_PROPERTIES
│   │   └── APP1_PREPROD_DATA
│   │
│   └── repo-b/
│       ├── APP2_LOGIN
│       └── APP2_PROPERTIES
│
└── prod/
    ├── repo-a/
    │   └── APP1_PROD_DATA
    │
    └── repo-b/
        └── APP2_PROD_DATA
```

The actual KV v2 design may store multiple fields at one repository-specific path.

For example:

```
secret/qa/repo-a
```

with fields:

```
APP1_LOGIN
APP1_PROPERTIES
APP1_PREPROD_DATA
```

This permits repository-level path authorization.

**Critical security consideration:** KV v2 policies authorize access to paths, not individual fields in the JSON document. If multiple repositories share a path, filtering fields in a workflow does not provide field-level isolation.

## 8.2 GitHub OIDC Authentication

The workflow should authenticate using GitHub's OIDC identity rather than storing a long-lived Vault token in GitHub Secrets.

High-level authentication flow:

```
GitHub Actions Job
       |
       v
GitHub OIDC Identity Token
       |
       v
HashiCorp Vault JWT Authentication
       |
       v
Vault Role Validation
       |
       v
Short-Lived Vault Token
       |
       v
Authorized Secret Retrieval
```

The Vault role should validate appropriate JWT claims, including:

- Repository identity.
- Approved workflow identity.
- Branch or ref restrictions where applicable.
- Environment restrictions where applicable.
- Token audience.

For reusable workflows, validate the actual caller and reusable workflow claims together. Do not assume that the reusable workflow's repository name alone identifies the caller.

## 8.3 Example Vault Policy

Illustrative policy for Repo A QA:

```
path "secret/data/qa/repo-a" {
  capabilities = ["read"]
}
```

A separate production policy can be configured:

```
path "secret/data/prod/repo-a" {
  capabilities = ["read"]
}
```

Production authorization should be controlled independently through Vault policies and GitHub Environment approval requirements.

Use the actual Vault KV mount and policy path configured in your organization.

# 9. Central Reusable Workflow

The reusable workflow is the central execution engine.

Its responsibilities are:

1. Accept workflow inputs.
2. Checkout the caller repository.
3. Locate and validate the manifest.
4. Authenticate with Vault.
5. Retrieve authorized data.
6. Deliver data according to the manifest.
7. Execute Maven.
8. Publish reports.
9. Clean up runtime data.

## 9.1 Reusable Workflow Contract

File: `.github/workflows/reusable-test-execution.yml`

```
name: Reusable Test Execution

on:
  workflow_call:
    inputs:
      test_type:
        required: true
        type: string

      environment:
        required: true
        type: string

permissions:
  contents: read
  id-token: write

jobs:
  test-execution:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout caller repository
        uses: actions/checkout@v4
        with:
          repository: ${{ github.repository }}
          ref: ${{ github.sha }}

      - name: Validate manifest
        run: |
          ./scripts/validate-manifest.sh \
            .github/Secret-manifest.yaml

      # Authenticate to Vault using approved OIDC integration.
      # Retrieve authorized fields and deliver them according
      # to the manifest.

      - name: Execute Maven tests
        run: |
          mvn clean test \
            -DtestType="${{ inputs.test_type }}" \
            -DtargetEnvironment="${{ inputs.environment }}"

      - name: Publish reports
        if: always()
        run: |
          ./scripts/publish-results.sh

      - name: Cleanup runtime data
        if: always()
        run: |
          ./scripts/cleanup-runtime-data.sh
```

This is the workflow skeleton. Vault authentication, data delivery and report publishing are intentionally delegated to dedicated scripts or actions.

**Implementation note:** The example uses `actions/checkout@v4` for readability. In production, pin actions to reviewed immutable commit SHAs and keep versions centrally governed.

# 10. Dynamic Test Data Delivery Engine

The delivery engine is responsible for converting retrieved Vault values into the runtime format requested by the manifest.

Two delivery mechanisms are supported.

## 10.1 Environment Variable Delivery

Suitable for:

- Small JSON credentials.
- Small runtime configuration objects.
- Properties content that the Java framework can parse from a string.

Java example:

```
String loginJson = System.getenv("APP1_LOGIN");
```

Parsing JSON:

```
JSONObject loginData = new JSONObject(loginJson);
```

Parsing properties:

```
String propertiesContent =
    System.getenv("APP1_PROPERTIES");

Properties properties = new Properties();

properties.load(
    new StringReader(propertiesContent)
);
```

Environment variables are strings. The manifest's `type` tells the application how to interpret the content; it does not change the underlying environment variable type.

## 10.2 Runtime File Delivery

Suitable for:

- Larger JSON datasets.
- Large properties files.
- Existing frameworks that already consume files.
- Test data that should be loaded on demand.

Example runtime output:

```
data/test/creds/
│
├── login.json
├── application.properties
├── preprod.json
└── prod.json
```

The existing framework can continue reading from its current file paths, minimizing code changes.

## 10.3 Example Delivery Script Logic

Illustrative Bash logic for delivering a retrieved value:

```
#!/usr/bin/env bash

set -euo pipefail
umask 077

KEY="${1:?Vault key required}"
MODE="${2:?Delivery mode required}"
VALUE="${3:?Value required}"

case "$MODE" in
  ENV)
    # Use a safe multiline delimiter and write to GITHUB_ENV.
    # The delimiter must not occur as a standalone line
    # in VALUE.
    DELIMITER="$(openssl rand -hex 16)"

    if grep -Fxq "$DELIMITER" <<< "$VALUE"; then
      echo "Multiline delimiter collision"
      exit 1
    fi

    {
      printf '%s<<%s\n' "$KEY" "$DELIMITER"
      printf '%s\n' "$VALUE"
      printf '%s\n' "$DELIMITER"
    } >> "$GITHUB_ENV"
    ;;

  FILE)
    echo "File delivery requires validated destination path."
    exit 2
    ;;

  *)
    echo "Unsupported delivery mode"
    exit 1
    ;;
esac
```

This illustrates the ENV delivery mechanism only. Production implementation should avoid passing secret payloads through command-line arguments, validate the environment variable name, and preferably process values through protected files or process memory.

For FILE delivery, write directly to a validated destination using a secure file-handling implementation. Do not accept arbitrary manifest paths.

For larger datasets, avoid exporting the entire content through `$GITHUB_ENV`.

## 10.4 Important GitHub Actions Environment Behavior

`GITHUB_ENV` makes variables available to subsequent steps in the same job.

It does not change the environment of the step that writes to it.

It also does not automatically transfer values to another job or another GitHub Actions workflow.

Avoid using workflow outputs for large secret payloads.

# 11. Parallel Execution and Memory Management

The platform must support multiple Maven forks and Cucumber threads.

The recommended lifecycle is:

```
GitHub Actions Job
       |
       v
Vault Retrieval (Once)
       |
       v
Runtime Data Generation (Once)
       |
       v
Maven Execution
       |
       +---- JVM Fork 1
       |
       +---- JVM Fork 2
       |
       +---- JVM Fork 3
       |
       +---- JVM Fork 4
       |
       v
Report Collection
       |
       v
Cleanup
```

## 11.1 Parallel Execution Principles

- Retrieve required Vault data once per job.
- Generate runtime files once per job.
- Avoid repeated Vault API calls from individual test scenarios.
- Keep test-data records immutable wherever possible.
- Use independent test accounts or data reservations where tests mutate shared records.
- Avoid shared mutable static objects across threads.
- Ensure each scenario has an independent data context.
- Avoid loading unnecessary datasets into every JVM.

## 11.2 Environment Variables Versus Files

| Consideration                 | ENV              | FILE                    |
| ----------------------------- | ---------------- | ----------------------- |
| Small credentials             | Suitable         | Suitable                |
| Large JSON data               | Less suitable    | Preferred               |
| OS environment limits         | Relevant         | Avoided                 |
| Child process inheritance     | Yes              | File path can be shared |
| Parsing memory                | Per JVM          | Per JVM                 |
| Lazy file access              | Not applicable   | Supported               |
| Existing file-based framework | Requires changes | Minimal changes         |

Important: FILE delivery does not automatically eliminate JVM memory usage.

Each JVM that parses a dataset creates its own Java objects. Files mainly avoid transporting large payloads through process environments and allow on-demand loading.

## 11.3 Performance Validation

Test at different parallelism levels.

| Scenario           | Forks | Threads per fork |
| ------------------ | ----- | ---------------- |
| Baseline           | 1     | 1                |
| Low parallelism    | 2     | 2                |
| Medium parallelism | 4     | 3                |
| High parallelism   | 4     | 4                |

Measure:

- Total execution duration.
- Peak memory usage.
- JVM startup overhead.
- Test-data parsing time.
- Failure and flakiness rate.
- Resource contention.

Choose settings based on measured results, not just the maximum available parallelism.

# 12. Java Framework Integration

The objective is to avoid unnecessary changes to the existing automation framework.

Where existing code reads:

```
File file = new File(
    "data/test/creds/login.json"
);
```

The new delivery mechanism can generate the same file before Maven execution.

For ENV-based delivery, a small configuration utility can provide a fallback:

```
public class TestDataLoader {

    public static String load(
        String envKey,
        String filePath
    ) throws IOException {

        String value = System.getenv(envKey);

        if (value != null && !value.isBlank()) {
            return value;
        }

        return Files.readString(
            Path.of(filePath)
        );
    }
}
```

JSON parsing:

```
String content = TestDataLoader.load(
    "APP1_LOGIN",
    "data/test/creds/login.json"
);

JSONObject json = new JSONObject(content);
```

This provides compatibility with both delivery mechanisms.

The framework should also validate required data and produce useful error messages without exposing sensitive values.

# 13. Failure Handling and Recovery

The platform must fail securely and provide actionable diagnostics.

| Failure condition             | Expected behavior                     |
| ----------------------------- | ------------------------------------- |
| Manifest missing              | Fail before test execution            |
| Invalid manifest schema       | Reject configuration                  |
| Unsupported delivery mode     | Fail validation                       |
| Vault authentication failure  | Fail securely                         |
| Missing Vault key             | Identify key name, never value        |
| Invalid JSON                  | Fail data validation                  |
| Runtime file creation failure | Stop execution                        |
| Maven test failure            | Publish available reports             |
| One repository fails          | Continue independent executions       |
| Cleanup failure               | Flag and investigate                  |
| Reporting failure             | Preserve individual execution records |

Retries should be limited to appropriate transient infrastructure failures.

Do not automatically retry all functional test failures.

# 14. Security Requirements

Security controls are mandatory design requirements.

| Control            | Implementation                             |
| ------------------ | ------------------------------------------ |
| Authentication     | GitHub OIDC                                |
| Secret storage     | HashiCorp Vault                            |
| Authorization      | Repository-specific Vault policies         |
| Production access  | Separate environment and approval controls |
| Runtime files      | Restrictive permissions                    |
| Secret logging     | Prohibited                                 |
| Git commits        | No runtime secrets                         |
| Workflow artifacts | Exclude secret-bearing files               |
| Cache              | Never cache secret-bearing files           |
| Tokens             | Short-lived and least-privilege            |
| Cleanup            | Execute even after test failure            |
| Audit              | Vault and GitHub execution logs            |

Additional considerations:

- Avoid logging shell commands containing secret values.
- Avoid passing secret payloads as process arguments.
- Be careful with `set -x`.
- Never publish runtime credential files as artifacts.
- Ensure self-hosted runners have dedicated cleanup and isolation controls.
- Remember that environment variables are accessible to processes running under the same job context; they are not a substitute for access isolation.
- For production data, require explicit approval and tightly scoped authorization.

GitHub-hosted runners are ephemeral, but runtime secrets still exist while the job is executing. Cleanup remains important.

# 15. Centralized Reporting and Observability

A centralized platform should provide a consolidated view of execution health.

## Proposed Dashboard Metrics

| Metric                          | Purpose                   |
| ------------------------------- | ------------------------- |
| Repositories onboarded          | Adoption                  |
| Total executions                | Platform utilization      |
| Smoke execution duration        | Deployment feedback       |
| Regression execution duration   | Regression efficiency     |
| Pass percentage                 | Automation health         |
| Failure classification          | Root-cause analysis       |
| Infrastructure failures         | Platform reliability      |
| Vault authentication failures   | Security visibility       |
| Runtime data retrieval duration | Data delivery performance |
| Flaky test rate                 | Test reliability          |

## Example Reporting Structure

```
Centralized Execution
│
├── Execution ID
├── Triggered By
├── Execution Timestamp
├── Target Environment
│
├── Repo A
│   ├── Test Type
│   ├── Run ID
│   ├── Status
│   ├── Duration
│   └── Report URL
│
├── Repo B
│   ├── Test Type
│   ├── Run ID
│   ├── Status
│   ├── Duration
│   └── Report URL
│
└── Consolidated Summary
    ├── Total Repositories
    ├── Passed
    ├── Failed
    └── Skipped
```

The orchestrator should track each dispatched run ID and collect the final status independently.

A failed application workflow must not erase results from other workflows.

# 16. Workflow Versioning and Governance

The centralized reusable workflow is a shared engineering dependency.

Versioning must therefore be controlled.

Recommended strategy:

```
Central-Automation/
│
├── v1.0.0
├── v1.1.0
└── v2.0.0
```

Suggested versioning policy:

- Patch: backward-compatible fixes.
- Minor: backward-compatible features.
- Major: breaking contract or manifest changes.

Application repositories should upgrade through controlled adoption.

The platform should maintain:

- Supported manifest versions.
- Reusable workflow release notes.
- Deprecation timelines.
- Backward compatibility rules.
- Rollback procedures.

# 17. Testing Strategy for the Platform

Before production onboarding, validate the platform itself.

## 17.1 Functional Validation

- Manifest with ENV delivery.
- Manifest with FILE delivery.
- JSON content retrieval.
- Properties content retrieval.
- Multiple Vault keys.
- Missing Vault key.
- Invalid manifest.
- Unsupported data type.
- Invalid destination path.

## 17.2 Security Validation

- Repo A cannot access Repo B secrets.
- QA identity cannot access PROD secrets.
- Unapproved workflow cannot authenticate.
- Expired Vault token is rejected.
- Secret values never appear in logs.
- Runtime files are not uploaded as artifacts.
- Cleanup executes after failures.

## 17.3 Parallel Execution Validation

- Multiple JVM forks.
- Multiple Cucumber threads.
- Concurrent data reads.
- Shared data mutation.
- Large JSON datasets.
- Repeated JVM initialization.
- Runner memory consumption.

## 17.4 Orchestration Validation

- Multiple repositories dispatched.
- One repository fails while others continue.
- Dispatch failure.
- Application workflow timeout.
- Result collection after failures.
- Duplicate dispatch prevention where required.

# 18. Implementation Roadmap

| Phase                          | Deliverables                                               |
| ------------------------------ | ---------------------------------------------------------- |
| Phase 1: Architecture          | Component contracts, Vault path structure, manifest schema |
| Phase 2: Core implementation   | OIDC, Vault retrieval, ENV/FILE delivery                   |
| Phase 3: Framework integration | Java data loader, Maven integration                        |
| Phase 4: Orchestration         | Central dispatch, execution tracking                       |
| Phase 5: Parallel optimization | Fork/thread tuning, memory and performance testing         |
| Phase 6: Reporting             | Consolidated dashboard and failure analytics               |
| Phase 7: Pilot                 | Three representative repositories                          |
| Phase 8: Production rollout    | Security sign-off, governance and onboarding               |

# 19. Acceptance Criteria

The platform should be considered production-ready only after the following criteria are demonstrated.

| Category       | Acceptance criterion                                        |
| -------------- | ----------------------------------------------------------- |
| Reusability    | Multiple repositories use the same reusable workflow        |
| Configuration  | Repository-specific manifest controls data requirements     |
| Security       | Repository-level Vault isolation is verified                |
| Authentication | No long-lived Vault token is required in GitHub Secrets     |
| Data delivery  | ENV and FILE delivery both work                             |
| Framework      | Existing file-based framework remains compatible            |
| Parallelism    | Multiple JVMs and threads execute reliably                  |
| Reliability    | Independent repositories continue after individual failures |
| Cleanup        | Runtime files are cleaned up after success and failure      |
| Reporting      | Centralized execution status is available                   |
| Governance     | Workflow and manifest versions are controlled               |
| Audit          | Vault and GitHub execution records are available            |

# 20. Success Metrics and Business Value

Measure the following before and after adoption.

| Metric                        | Baseline       | Target    |
| ----------------------------- | -------------- | --------- |
| Repository onboarding effort  | To be measured | Reduced   |
| Duplicated workflow code      | To be measured | Reduced   |
| Manual test-data preparation  | To be measured | Minimized |
| Regression execution duration | To be measured | Improved  |
| Secret management exceptions  | To be measured | Reduced   |
| Execution reporting effort    | To be measured | Reduced   |
| Platform adoption             | To be measured | Increased |

Do not claim savings without actual measurements.

A useful ROI calculation is:

**Annual engineering hours saved = (Previous maintenance hours − New maintenance hours) × Number of maintenance cycles**

Additional value can be measured through reduced onboarding effort, faster feedback and fewer security exceptions.

# 21. Architecture Principles

The platform follows these design principles:

1. Single Responsibility: orchestration, secret retrieval, delivery and execution remain separate.
2. Open/Closed: new repositories and test-data requirements should be added through configuration.
3. Liskov Substitution: all participating repositories follow the same reusable workflow contract.
4. Interface Segregation: callers provide only relevant execution parameters.
5. Dependency Inversion: test execution should depend on a data-delivery contract rather than directly on Vault implementation details.
6. Least Privilege: repository identity determines permitted Vault access.
7. Secure by Default: missing or unauthorized data must stop execution.
8. Fail Independently: one repository failure should not stop unrelated executions.
9. Observable by Design: every execution should have traceable identifiers and results.
10. Configuration over Duplication: application-specific behavior belongs in manifests and approved configuration.

# 22. Conclusion

The proposed Centralized Test Execution & Secure Test Data Management Platform provides a common foundation for executing automation across multiple repositories.

By combining centralized orchestration, reusable workflows, manifest-driven configuration, HashiCorp Vault integration and parallel Maven execution, the solution establishes a scalable and governed automation execution model.

The design minimizes duplication while retaining application-level flexibility and security isolation.

The recommended approach is to validate the architecture through a representative multi-repository pilot, measure performance and engineering-effort improvements, obtain security approval, and progressively onboard additional automation repositories.

**Final architectural vision:**

One central execution platform. Multiple application repositories. One standardized execution contract. Secure repository-specific test data. Consistent reporting and governance.

---

# Appendix A — Implementation Decisions to Finalize

The following decisions should be confirmed before production implementation:

1. Final Vault KV mount and repository/environment path convention.
2. Approved GitHub OIDC role and JWT claim restrictions.
3. Manifest schema validation implementation.
4. Vault retrieval and data delivery script implementation.
5. ENV delivery size limits and FILE delivery rules.
6. GitHub-hosted versus self-hosted runner strategy.
7. Maven Surefire/Failsafe fork and thread configuration.
8. Centralized run tracking and reporting mechanism.
9. Workflow release and upgrade strategy.
10. Security, DevOps and application-team ownership.

# Appendix B — Important Implementation Notes

- GitHub Actions `workflow_call` provides a reusable workflow contract; it does not automatically make the reusable workflow's repository the application repository.
- Use the caller repository context and caller commit SHA when checking out application code.
- GitHub-hosted runner files do not persist as a normal workspace after the hosted job is discarded.
- `$GITHUB_ENV` values are available to subsequent steps in the same job, not the current step or separate jobs.
- Vault KV v2 policies authorize secret paths, not individual fields inside a secret document.
- A file-based delivery mechanism does not eliminate Java object memory consumption when multiple JVMs parse the same dataset.
- A reusable workflow must not elevate permissions beyond those granted by its caller.
- Production workflows should use immutable action and reusable workflow references.
- Treat all manifest content as untrusted configuration until it has been validated.

**Document owner:** Automation Engineering / SDET Platform Team\
**Reviewers:** Platform Engineering, Security Engineering, Application Automation Leads\
**Next review:** Following completion of the initial three-repository pilot.
