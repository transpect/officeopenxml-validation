<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
                xmlns:c="http://www.w3.org/ns/xproc-step"
                version="1.0"
                name="part-check">

  <!--
    Standalone test harness for the officeopenxml-validation core logic:
    dynamic schema flavor selection (xsl/schema-selection.xsl), MCE
    preprocessing (xsl/mce-normalize.xsl) and RelaxNG validation.

    Uses only standard XProc 1.0 steps so it runs with any XML Calabash,
    without the transpect extension steps that xpl/wml-check.xpl requires
    for the full docx pipeline.

    Example:
      calabash test/part-check.xpl source=test/fxt/transitional-mixed.xml \
        result=report.xml conformance=auto mce-preprocessing=yes
  -->

  <p:input port="source" primary="true"/>
  <p:output port="result" primary="true">
    <p:pipe step="summary" port="result"/>
  </p:output>

  <p:option name="conformance" select="'auto'"/>
  <p:option name="mce-preprocessing" select="'yes'"/>
  <p:option name="rng-name" select="'WordprocessingML_Main_Document.rng'"/>

  <p:identity name="input-doc"/>

  <p:xslt name="schema-selection">
    <p:input port="source">
      <p:pipe step="input-doc" port="result"/>
    </p:input>
    <p:input port="stylesheet">
      <p:document href="../xsl/schema-selection.xsl"/>
    </p:input>
    <p:with-param name="conformance" select="$conformance"/>
    <p:with-param name="rng-name" select="$rng-name"/>
    <p:input port="parameters"><p:empty/></p:input>
  </p:xslt>

  <p:load name="load-rng">
    <p:with-option name="href"
      select="concat('../schema/', normalize-space(.))">
      <p:pipe step="schema-selection" port="result"/>
    </p:with-option>
  </p:load>

  <p:xslt name="mce-normalize">
    <p:input port="source">
      <p:pipe step="input-doc" port="result"/>
    </p:input>
    <p:input port="stylesheet">
      <p:document href="../xsl/mce-normalize.xsl"/>
    </p:input>
    <p:with-param name="active" select="$mce-preprocessing"/>
    <p:input port="parameters"><p:empty/></p:input>
  </p:xslt>

  <p:try name="validate">
    <p:group>
      <p:validate-with-relax-ng name="val" assert-valid="true">
        <p:input port="source">
          <p:pipe step="mce-normalize" port="result"/>
        </p:input>
        <p:input port="schema">
          <p:pipe step="load-rng" port="result"/>
        </p:input>
      </p:validate-with-relax-ng>
    </p:group>
    <p:catch name="catch">
      <p:identity name="caught">
        <p:input port="source">
          <p:pipe step="catch" port="error"/>
        </p:input>
      </p:identity>
    </p:catch>
  </p:try>

  <p:wrap-sequence name="errors-wrapped" wrapper="c:errors-raw"/>

  <p:xslt name="summary">
    <p:input port="source">
      <p:pipe step="errors-wrapped" port="result"/>
    </p:input>
    <p:input port="stylesheet">
      <p:inline>
        <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                        xmlns:xs="http://www.w3.org/2001/XMLSchema"
                        xmlns:c="http://www.w3.org/ns/xproc-step"
                        version="2.0">
          <xsl:param name="selection" required="yes" as="xs:string"/>
          <xsl:template match="/">
            <c:validation-report flavor="{if (starts-with($selection, 'strict/')) then 'strict' else 'transitional'}"
                                 rng="{normalize-space($selection)}">
              <xsl:copy-of select="//c:error"/>
            </c:validation-report>
          </xsl:template>
        </xsl:stylesheet>
      </p:inline>
    </p:input>
    <p:with-param name="selection" select=".">
      <p:pipe step="schema-selection" port="result"/>
    </p:with-param>
    <p:input port="parameters"><p:empty/></p:input>
  </p:xslt>

</p:declare-step>
