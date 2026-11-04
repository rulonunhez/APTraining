package com.aptraining;

import com.aptraining.config.AwsProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties(AwsProperties.class)
public class ApTrainingBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(ApTrainingBackendApplication.class, args);
	}

}