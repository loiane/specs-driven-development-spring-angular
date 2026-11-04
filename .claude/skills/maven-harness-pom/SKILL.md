---
name: maven-harness-pom
description: Reference Maven POM fragments for the full harness — Spotless, Checkstyle, SpotBugs, Error Prone, JaCoCo, PIT, OpenAPI generator + diff, OWASP dependency check, Surefire/Failsafe. Use when wiring the harness into a new project or upgrading a brownfield POM.
when_to_use:
  - Phase E setup (`/onboard`).
  - Adding a missing harness layer to a brownfield repo.
authoritative_references:
  - https://maven.apache.org/plugins/
  - .claude/skills/jacoco-coverage-policy/SKILL.md
  - .claude/skills/pit-mutation-tuning/SKILL.md
---

# Maven harness POM fragments

Each fragment is a drop-in `<plugin>` block. Pin versions; `harness.sh` warns if they drift out of date by more than one minor.

## Properties (top of the POM)

```xml
<properties>
    <java.version>25</java.version>
    <maven.compiler.release>25</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>

    <spring-boot.version>4.0.0</spring-boot.version>

    <spotless.version>2.46.1</spotless.version>
    <checkstyle.version>11.0.0</checkstyle.version>
    <maven-checkstyle.version>3.6.0</maven-checkstyle.version>
    <spotbugs.version>4.9.4</spotbugs.version>
    <spotbugs-maven.version>4.9.4.0</spotbugs-maven.version>
    <error-prone.version>2.40.0</error-prone.version>
    <jacoco.version>0.8.12</jacoco.version>
    <pitest.version>1.17.0</pitest.version>
    <pitest-junit5.version>1.2.1</pitest-junit5.version>
    <archunit.version>1.4.1</archunit.version>
    <testcontainers.version>1.21.0</testcontainers.version>
    <openapi-generator.version>7.10.0</openapi-generator.version>
    <openapi-diff.version>2.2.1</openapi-diff.version>
    <dependency-check.version>10.0.4</dependency-check.version>
    <surefire.version>3.5.2</surefire.version>
</properties>
```

## Spotless (format)

```xml
<plugin>
    <groupId>com.diffplug.spotless</groupId>
    <artifactId>spotless-maven-plugin</artifactId>
    <version>${spotless.version}</version>
    <configuration>
        <java>
            <googleJavaFormat>
                <version>1.27.0</version>
                <style>GOOGLE</style>
            </googleJavaFormat>
            <removeUnusedImports/>
            <importOrder/>
        </java>
        <pom>
            <sortPom/>
        </pom>
    </configuration>
    <executions>
        <execution>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>
```

## Checkstyle

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-checkstyle-plugin</artifactId>
    <version>${maven-checkstyle.version}</version>
    <dependencies>
        <dependency>
            <groupId>com.puppycrawl.tools</groupId>
            <artifactId>checkstyle</artifactId>
            <version>${checkstyle.version}</version>
        </dependency>
    </dependencies>
    <configuration>
        <configLocation>checkstyle.xml</configLocation>
        <failOnViolation>true</failOnViolation>
        <consoleOutput>true</consoleOutput>
        <includeTestSourceDirectory>true</includeTestSourceDirectory>
    </configuration>
    <executions>
        <execution>
            <phase>verify</phase>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>
```

## SpotBugs

```xml
<plugin>
    <groupId>com.github.spotbugs</groupId>
    <artifactId>spotbugs-maven-plugin</artifactId>
    <version>${spotbugs-maven.version}</version>
    <configuration>
        <effort>Max</effort>
        <threshold>Low</threshold>
        <failOnError>true</failOnError>
        <xmlOutput>true</xmlOutput>
        <plugins>
            <plugin>
                <groupId>com.h3xstream.findsecbugs</groupId>
                <artifactId>findsecbugs-plugin</artifactId>
                <version>1.13.0</version>
            </plugin>
        </plugins>
    </configuration>
    <executions>
        <execution>
            <phase>verify</phase>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>
```

## Error Prone (compiler arg)

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-compiler-plugin</artifactId>
    <configuration>
        <compilerArgs>
            <arg>-XDcompilePolicy=simple</arg>
            <arg>--should-stop=ifError=FLOW</arg>
            <arg>-Xplugin:ErrorProne -XepDisableWarningsInGeneratedCode</arg>
        </compilerArgs>
        <annotationProcessorPaths>
            <path>
                <groupId>com.google.errorprone</groupId>
                <artifactId>error_prone_core</artifactId>
                <version>${error-prone.version}</version>
            </path>
        </annotationProcessorPaths>
    </configuration>
</plugin>
```

## JaCoCo

See `jacoco-coverage-policy` skill.

## PIT

See `pit-mutation-tuning` skill. Wire into a `pit` profile to keep default builds fast:

```xml
<profiles>
  <profile>
    <id>pit</id>
    <build>
      <plugins><plugin><groupId>org.pitest</groupId>...</plugin></plugins>
    </build>
  </profile>
</profiles>
```

## OpenAPI generator

```xml
<plugin>
    <groupId>org.openapitools</groupId>
    <artifactId>openapi-generator-maven-plugin</artifactId>
    <version>${openapi-generator.version}</version>
    <executions>
        <execution>
            <goals><goal>generate</goal></goals>
            <configuration>
                <inputSpec>${project.basedir}/src/main/resources/openapi/openapi.yaml</inputSpec>
                <generatorName>spring</generatorName>
                <library>spring-boot</library>
                <configOptions>
                    <interfaceOnly>true</interfaceOnly>
                    <useSpringBoot3>true</useSpringBoot3>
                    <useTags>true</useTags>
                    <useJakartaEe>true</useJakartaEe>
                    <dateLibrary>java8</dateLibrary>
                </configOptions>
            </configuration>
        </execution>
    </executions>
</plugin>
```

## OWASP Dependency Check

```xml
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>${dependency-check.version}</version>
    <configuration>
        <failBuildOnCVSS>7</failBuildOnCVSS>
        <suppressionFiles>
            <suppressionFile>dependency-check-suppressions.xml</suppressionFile>
        </suppressionFiles>
    </configuration>
    <executions>
        <execution>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>
```

## Surefire / Failsafe split

Surefire = unit. Failsafe = integration (Testcontainers).

Naming convention:

- Unit tests: `*Test.java`
- IT tests: `*IT.java`

```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>${surefire.version}</version>
    <configuration>
        <excludes><exclude>**/*IT.java</exclude></excludes>
    </configuration>
</plugin>
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-failsafe-plugin</artifactId>
    <version>${surefire.version}</version>
    <executions>
        <execution>
            <goals>
                <goal>integration-test</goal>
                <goal>verify</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```
