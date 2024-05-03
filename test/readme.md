# How to run the tests

Run the tests from within the `test` directory

```
cd ../
go mod init github.com/ministryofjustice/modernisation-platform-terraform-iam-superadmins
go mod tidy
go mod download
aws-vault exec mod -- go test -v
```

Upon successful run, you should see an output similar to the below

```
TestSNSCreation 2022-07-01T11:34:12+01:00 logger.go:66: Destroy complete! Resources: 2 destroyed.
TestSNSCreation 2022-07-01T11:34:12+01:00 logger.go:66:
PASS
ok  	pagerduty_integration_test.go	74.301s

```

## References

1. https://terratest.gruntwork.io/docs/getting-started/quick-start/
2. https://github.com/ministryofjustice/modernisation-platform-terraform-pagerduty-integration/blob/main/.github/workflows/go-terratest.yml
