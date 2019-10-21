<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" 
  xmlns:c="http://www.w3.org/ns/xproc-step"
  xmlns:cx="http://xmlcalabash.com/ns/extensions" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema" 
  xmlns:tr="http://transpect.io"
  xmlns:tr-internal="http://transpect.io/internal"
  xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" 
  version="1.0" 
  name="wml-check" 
  type="tr:wml-check">

  <!-- 
    Validation of XML content of MS Word .docx files.
    At the moment without validation of:
    - [Content_Types].xml
    - _rels/.rels
    - docProps/app.xml
    - docProps/core.xml
    - docProps/custom.xml
  -->

  <p:option name="file" required="true"/>
  <p:option name="validate-only-regex" select="''"/>
  <p:option name="debug" select="'no'"/>
  <p:option name="report-family-prefix" select="'docx'"/>
  <p:option name="projectspecific-exclusion_regex" select="''"/>

  <p:output port="result" primary="true">
    <p:pipe step="val-component-wrapper" port="result"/>
  </p:output>

  <p:output port="report" primary="false">
    <p:pipe step="build-report" port="result"/>
  </p:output>

  <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl" />
  <p:import href="http://transpect.io/calabash-extensions/rng-extension/xpl/rng-schematron.xpl" />
  <p:import href="http://transpect.io/calabash-extensions/unzip-extension/internal-unzip-declaration.xpl" />

  <tr-internal:unzip name="unzip">
    <p:with-option name="zip" select="$file" />
    <p:with-option name="dest-dir" select="concat($file, '.tmp')"/>
    <p:with-option name="overwrite" select="'yes'" />
  </tr-internal:unzip>

  <p:for-each name="val-components">
    <p:iteration-source 
      select="/c:files
                /c:file
                  [if($validate-only-regex != '') then
                   matches(
                     @name, 
                     $validate-only-regex
                   ) else true()
                  ][not(matches(@name, 'Content_Types|word/(people|commentsEx)|docProps/(app|core).xml|docProps/custom.xml|.rels'))]" />
    <p:output port="result" primary="true">
      <p:pipe step="val-component" port="text" />
    </p:output>

    <p:xslt name="rng-selection">
      <p:input port="stylesheet">
        <p:inline>
          <xsl:stylesheet version="2.0">
            <xsl:param name="base-uri"/>
            <xsl:param name="debug"/>
            <xsl:template match="/c:file">
              <c:result>
                <xsl:variable name="rng-file" as="xs:string">
                  <xsl:choose>
                    <xsl:when test="@name = 'word/styles.xml'">WordprocessingML_Style_Definitions.rng</xsl:when>
                    <xsl:when test="@name = 'word/comments.xml'">WordprocessingML_Comments.rng</xsl:when>
                    <xsl:when test="@name = 'word/numbering.xml'">WordprocessingML_Numbering_Definitions.rng</xsl:when>
                    <xsl:when test="@name = 'word/footnotes.xml'">WordprocessingML_Footnotes.rng</xsl:when>
                    <xsl:when test="@name = 'word/endnotes.xml'">WordprocessingML_Endnotes.rng</xsl:when>
                    <xsl:when test="@name = 'word/settings.xml'">WordprocessingML_Document_Settings.rng</xsl:when>
                    <xsl:when test="@name = 'word/fontTable.xml'">WordprocessingML_Font_Table.rng</xsl:when>
                    <xsl:when test="@name = 'word/document.xml'">WordprocessingML_Main_Document.rng</xsl:when>
                    <xsl:when test="starts-with(@name, 'customXml/itemProps')">Shared_Custom_XML_Data_Storage_Properties.rng</xsl:when>
                    <xsl:when test="starts-with(@name, 'customXml/item')">Shared_Bibliography.rng</xsl:when>
                    <xsl:when test="starts-with(@name, 'word/header')">WordprocessingML_Header.rng</xsl:when>
                    <xsl:when test="starts-with(@name, 'word/footer')">WordprocessingML_Footer.rng</xsl:when>
                    <xsl:when test="starts-with(@name, 'word/theme/theme')">DrawingML_Theme.rng</xsl:when>
                    <xsl:when test="@name = 'word/webSettings.xml'">WordprocessingML_Web_Settings.rng</xsl:when>
                    <xsl:otherwise>
                      _unknown_
                      <xsl:message select="'ERROR: unknown file', xs:string(@name), 'for determining RNG schema file.&#xa;'" terminate="no"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:variable>
                <xsl:if test="$debug = 'yes'">
                  <xsl:message select="'Validating', xs:string(@name), 'with', $rng-file"/>
                </xsl:if>
                <xsl:sequence select="$rng-file"/>
              </c:result>
            </xsl:template>
          </xsl:stylesheet>
        </p:inline>
      </p:input>
      <p:with-param name="base-uri" select="base-uri()"/>
      <p:with-param name="debug" select="$debug"/>
      <p:input port="parameters"><p:empty/></p:input>
    </p:xslt>

    <p:load name="load">
      <p:with-option name="href" select="resolve-uri(/c:file/@name, base-uri())">
        <p:pipe step="val-components" port="current"/>
      </p:with-option>
    </p:load>

    <tr:validate-with-rng-sch name="val-component">
      <p:with-option name="rngfile" 
        select="resolve-uri(
                  concat('../schema/', /c:result), 
                  static-base-uri()
                )">
        <p:pipe step="rng-selection" port="result"/>
      </p:with-option>
      <p:with-option name="info-messages" select="'true'" />
    </tr:validate-with-rng-sch>
    <p:sink/>

  </p:for-each>

  <p:wrap-sequence group-adjacent="true()" wrapper="c:results" name="val-component-wrapper"/>

  <p:xslt name="build-report">
    <p:input port="stylesheet">
      <p:inline>
        <xsl:stylesheet version="2.0">
          <xsl:param name="base-uri"/>
          <xsl:param name="debug"/>
          <xsl:param name="report-family-prefix"/>
          <xsl:param name="projectspecific-exclusion_regex" select="''"/>
          <xsl:template match="c:results">
            <xsl:variable name="container-file" select="tokenize($base-uri, '/')[last()]"/>
            <xsl:variable name="single-reports">
              <xsl:apply-templates/>
            </xsl:variable>
            <svrl:schematron-output title="Office Open XML Validation" schemaVersion="" tr:step-name="wml-rng-check"
        tr:rule-family="{$report-family-prefix} Validation">
              <svrl:active-pattern id="contentchecker_results" name="contentchecker_results"/>
              <svrl:fired-rule context="*[@srcpath]"/>
              <xsl:if test="not($single-reports/*)">
                <svrl:successful-report test="true()" id="{$container-file}" role="info">
                  <svrl:text>
                    <span class="srcpath" xmlns="http://www.w3.org/1999/xhtml">BC_orphans</span>
                    Schema validation summary of <xsl:value-of select="count(rng-sch-validation-report)"/> container files in <xsl:value-of select="$container-file"/> went fine.
                    <br xmlns="http://www.w3.org/1999/xhtml"/>
                    <br xmlns="http://www.w3.org/1999/xhtml"/>
                    All <xsl:value-of select="count(rng-sch-validation-report[normalize-space(.) = 'ok'])"/> checked files are valid.
                    <br xmlns="http://www.w3.org/1999/xhtml"/>
                    <br xmlns="http://www.w3.org/1999/xhtml"/>
                  </svrl:text>
                </svrl:successful-report>
              </xsl:if>
              <xsl:sequence select="$single-reports"/>
            </svrl:schematron-output>
          </xsl:template>
          <xsl:template match="rng-sch-validation-report[normalize-space(.) = 'ok']" priority="1"/>
          <xsl:template match="rng-sch-validation-report">
            <xsl:variable name="id-suffix" 
              select="replace(tokenize(@xml-file, '/')[last()], '^.+/(.+)\.xml$', '$1')"/>
            <xsl:for-each select="tokenize(., '\n')[normalize-space()]
                                                  [if($projectspecific-exclusion_regex = '')
                                                  then true()
                                                  else 
                                                    if(matches(., $projectspecific-exclusion_regex)) 
                                                    then false() else true()]">
              <svrl:successful-report test="true()" role="warning" id="{$report-family-prefix}-{$id-suffix}">
                <svrl:text>
                  <span class="srcpath" xmlns="http://www.w3.org/1999/xhtml">BC_orphans</span>
                  <!-- example line:
                  1:1611:org.xml.sax.SAXParseException; systemId: file:/var/autofs/data/sandbox/pglatza/vde-transpect/test/sts2dke/list_array/list-array_de.xml.docx.tmp/word/document.xml; lineNumber: 1; columnNumber: 1611; attribute "mc:Ignorable" not allowed here; expected attribute "w:conformance" -->
                  <br xmlns="http://www.w3.org/1999/xhtml"/>
                  <xsl:value-of select="replace(., '^.+lineNumber: \d+; columnNumber: \d+;(.+)$', '$1')"/>
                  <br xmlns="http://www.w3.org/1999/xhtml"/>
                  <br xmlns="http://www.w3.org/1999/xhtml"/>
                  Line: <xsl:value-of select="replace(., '^.+lineNumber: (\d+); columnNumber: \d+;.+$', '$1')"/>
                  <br xmlns="http://www.w3.org/1999/xhtml"/>
                  Column: <xsl:value-of select="replace(., '^.+lineNumber: \d+; columnNumber: (\d+);.+$', '$1')"/>
                  <br xmlns="http://www.w3.org/1999/xhtml"/>
                  <br xmlns="http://www.w3.org/1999/xhtml"/>
                </svrl:text>
              </svrl:successful-report>
            </xsl:for-each>
          </xsl:template>
        </xsl:stylesheet>
      </p:inline>
    </p:input>
    <p:with-param name="base-uri" select="$file"/>
    <p:with-param name="debug" select="$debug"/>
    <p:with-param name="report-family-prefix" select="$report-family-prefix"/>
    <p:with-param name="projectspecific-exclusion_regex" select="$projectspecific-exclusion_regex"/>
    <p:input port="parameters"><p:empty/></p:input>
  </p:xslt>

</p:declare-step>