package main

import (
	"regexp"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestMemberVPC(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "./unit-test",
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Test VPC ID
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	assert.Contains(t, vpcId, "vpc-")
	assert.Regexp(t, regexp.MustCompile(`vpc-*`), vpcId)

	// Test secondary CIDR blocks
	secondaryCidrBlocks := terraform.OutputList(t, terraformOptions, "secondary_cidr_blocks")
	assert.Equal(t, 1, len(secondaryCidrBlocks), "Should have 1 secondary CIDR block")
	assert.Equal(t, "192.168.16.0/20", secondaryCidrBlocks[0], "Secondary CIDR should be 192.168.16.0/20")

	// Test secondary CIDR subnet IDs
	secondaryCidrSubnetIds := terraform.OutputList(t, terraformOptions, "secondary_cidr_subnet_ids")
	assert.Greater(t, len(secondaryCidrSubnetIds), 0, "Should have at least one secondary CIDR subnet")
	for _, subnetId := range secondaryCidrSubnetIds {
		assert.Contains(t, subnetId, "subnet-")
	}
}
