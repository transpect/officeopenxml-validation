<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                version="2.0">

  <!--
    MCE preprocessing (ECMA-376 Part 3, Markup Compatibility and Extensibility)

    Prepares an OOXML package part for validation against the ECMA-376 RelaxNG
    schemas. Conforming consumers must ignore markup in namespaces that the
    document root lists in @mc:Ignorable and must resolve mc:AlternateContent
    to the first mc:Choice whose @Requires prefixes they understand, or to the
    mc:Fallback. Word's w14/w15/w16 extension markup is typical ignorable
    content; without this preprocessing it shows up as schema violations
    although every Word version handles these files correctly.

    Limitations (deliberate simplifications, both rare in Word-generated parts):
    - Namespace prefixes are resolved against the root element only, not
      against possible per-element redeclarations.
    - @mc:ProcessContent is honored in the simple form: if an ignorable element
      carries a non-empty @mc:ProcessContent, its children are processed
      instead of being dropped along with it.
  -->

  <xsl:param name="active" as="xs:string" select="'yes'"/>
  <xsl:param name="abs-file-path" as="xs:string" select="''"/>

  <xsl:variable name="root" select="/*"/>

  <xsl:variable name="ignorable-prefixes" as="xs:string*"
                select="tokenize(normalize-space(string-join($root/@mc:Ignorable, ' ')), '\s+')[.]"/>

  <xsl:variable name="ignorable-uris" as="xs:string*">
    <xsl:for-each select="$ignorable-prefixes">
      <xsl:variable name="prefix" select="."/>
      <xsl:variable name="uri" select="namespace-uri-for-prefix($prefix, $root)"/>
      <xsl:choose>
        <xsl:when test="string($uri)">
          <xsl:sequence select="string($uri)"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:message select="'WARNING: prefix ''', $prefix,
                               ''' is listed in mc:Ignorable but not declared on the root element of ', $abs-file-path"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:variable>

  <!-- prefixes the (hypothetical) consumer understands: all declared on the
       root except those declared ignorable -->
  <xsl:variable name="understood-prefixes" as="xs:string*"
                select="in-scope-prefixes($root)[not(. = $ignorable-prefixes)]"/>

  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="$active = 'yes'">
        <xsl:apply-templates select="node()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="."/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- resolve mc:AlternateContent: first Choice whose Requires prefixes are
       all understood, else the Fallback -->
  <xsl:template match="mc:AlternateContent" priority="2">
    <xsl:variable name="choices" as="element(mc:Choice)*"
                  select="mc:Choice[every $req in tokenize(normalize-space(@Requires), '\s+')[.]
                                     satisfies ($req = $understood-prefixes)]"/>
    <xsl:choose>
      <xsl:when test="exists($choices)">
        <xsl:apply-templates select="$choices[1]/node()"/>
      </xsl:when>
      <xsl:when test="mc:Fallback">
        <xsl:apply-templates select="mc:Fallback[1]/node()"/>
      </xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:template>

  <!-- only reached if mc:MustUnderstand or stray Choice/Fallback occur outside
       an AlternateContent parent: unwrap MustUnderstand, drop the rest -->
  <xsl:template match="mc:MustUnderstand" priority="1">
    <xsl:apply-templates select="node()"/>
  </xsl:template>
  <xsl:template match="mc:Choice | mc:Fallback" priority="1"/>

  <!-- drop markup compatibility attributes and attributes in ignorable
       namespaces (e.g. w14:paraId, w15:restartNumberingAfterBreak) -->
  <xsl:template match="@mc:Ignorable | @mc:ProcessContent | @mc:MustUnderstand" priority="1"/>
  <xsl:template match="@*[namespace-uri(.) = $ignorable-uris]" priority="1"/>

  <!-- drop elements in ignorable namespaces, but honor @mc:ProcessContent -->
  <xsl:template match="*[namespace-uri(.) = $ignorable-uris]" priority="0.5">
    <xsl:choose>
      <xsl:when test="normalize-space(@mc:ProcessContent)">
        <xsl:apply-templates select="node()"/>
      </xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
