<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:c="http://www.w3.org/ns/xproc-step"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="2.0">

  <!--
    Dynamic OOXML schema flavor selection.

    ISO/IEC 29500 strict and transitional parts are distinguished by the
    namespace of the part's root element (strict uses purl.oclc.org URIs,
    transitional uses schemas.openxmlformats.org URIs). The result is the
    relative path of the RelaxNG schema inside the repository's schema
    directory: the strict set lives in schema/strict/, the transitional set
    (the original repository content) directly in schema/.

    Parts whose root namespace is not an OOXML namespace (customXml/item*.xml
    with application-specific vocabularies) are validated against the base
    (transitional) schema set, which is identical in both flavors for these
    permissive schemas.
  -->

  <xsl:param name="conformance" as="xs:string" select="'auto'"/>
  <xsl:param name="rng-name" as="xs:string" required="yes"/>
  <xsl:param name="abs-file-path" as="xs:string" select="''"/>

  <xsl:template match="/">
    <xsl:variable name="root-ns" select="namespace-uri(/*)" as="xs:string"/>
    <xsl:variable name="flavor" as="xs:string">
      <xsl:choose>
        <xsl:when test="$conformance = 'strict' or $conformance = 'transitional'">
          <xsl:sequence select="$conformance"/>
        </xsl:when>
        <xsl:when test="starts-with($root-ns, 'http://purl.oclc.org/ooxml/')">
          <xsl:sequence select="'strict'"/>
        </xsl:when>
        <xsl:when test="starts-with($root-ns, 'http://schemas.openxmlformats.org/')">
          <xsl:sequence select="'transitional'"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message select="'NOTE: root namespace ''', $root-ns, ''' of ', $abs-file-path,
                               ' is not an OOXML namespace; using the base (transitional) schema set.'"/>
          <xsl:sequence select="'transitional'"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <c:result flavor="{$flavor}">
      <xsl:value-of select="if ($flavor = 'strict') then concat('strict/', $rng-name) else $rng-name"/>
    </c:result>
  </xsl:template>

</xsl:stylesheet>
