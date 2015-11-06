<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">

    <xsl:output method="xml" omit-xml-declaration="no" indent="yes"/>
    <!-- xsl:strip-space elements="*"/ -->

    <xsl:template match="App_Data/@App[. != 'MOD']">
        <xsl:attribute name="App">MOD</xsl:attribute>
    </xsl:template>
    <!-- Copy everything -->
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>

    <xsl:param name="feedFilePath" select="'{feed_file_path}/'"/>

    <xsl:template match="/ADI/Asset/Asset/Content">
        <xsl:variable name="assetClass" select="../Metadata/AMS/@Asset_Class"/>
        <xsl:variable name="contentValue" select="../Content/@Value"/>
        <xsl:if test="not($contentValue = '')">
            <xsl:choose>
                <xsl:when test="$assetClass = 'movie'">
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="$feedFilePath"/>
                            <xsl:value-of select="$contentValue"/></xsl:attribute>
                    </xsl:element>
                </xsl:when>
                <xsl:when test="$assetClass = 'preview'">
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="$feedFilePath"/>
                            <xsl:value-of select="$contentValue"/></xsl:attribute>
                    </xsl:element>
                </xsl:when>
                <xsl:when test="$assetClass = 'poster'">
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="$feedFilePath"/>
                            <xsl:value-of select="$contentValue"/></xsl:attribute>
                    </xsl:element>
                </xsl:when>
                <xsl:when test="$assetClass = 'banner'">
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="$feedFilePath"/>
                            <xsl:value-of select="$contentValue"/></xsl:attribute>
                    </xsl:element>
                </xsl:when>
                <xsl:when test="$assetClass = 'series_Poster'">
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="$feedFilePath"/>
                            <xsl:value-of select="$contentValue"/></xsl:attribute>
                    </xsl:element>
                </xsl:when>
                <xsl:when test="$assetClass = 'box_cover'">
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="$feedFilePath"/>
                            <xsl:value-of select="$contentValue"/></xsl:attribute>
                    </xsl:element>
                </xsl:when>
                <xsl:when test="$assetClass = 'closedCaption'">
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="$feedFilePath"/>
                            <xsl:value-of select="$contentValue"/></xsl:attribute>
                    </xsl:element>
                </xsl:when>
                <xsl:when test="$assetClass = 'background'">
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="$feedFilePath"/>
                            <xsl:value-of select="$contentValue"/></xsl:attribute>
                    </xsl:element>
                </xsl:when>
                <xsl:when test="$assetClass = 'audio'">
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="$feedFilePath"/>
                            <xsl:value-of select="$contentValue"/></xsl:attribute>
                    </xsl:element>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:element name="Content">
                        <xsl:attribute name="Value">
                            <xsl:value-of select="../Content/@Value"/>
                        </xsl:attribute>
                    </xsl:element>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:if>

        <xsl:if test="$contentValue = ''">
            <xsl:element name="Content">
                <xsl:attribute name="Value">
                    <xsl:value-of select="../Content/@Value"/>
                </xsl:attribute>
            </xsl:element>
        </xsl:if>
        <xsl:apply-templates/>
    </xsl:template>
</xsl:stylesheet>
