namespace P3.TXL.Payment.Documentation;

/// <summary>
/// Resolves and displays HTML documentation resources stored in the extension's
/// resource folder. Attempts to load a language-specific variant of the resource
/// first (e.g. user-guide.de-DE.html), falling back to the base English file
/// (e.g. user-guide.html) if no localized version is available.
/// </summary>
codeunit 51109 "Doc Viewer"
{
    Access = Internal;

    /// <summary>
    /// Resolves the best available language variant of the given HTML resource
    /// and opens it in the BC HTML Renderer page.
    /// </summary>
    /// <param name="BaseResourceName">
    /// The base resource file name without language suffix, e.g. 'user-guide.html'.
    /// </param>
    procedure ShowDocument(BaseResourceName: Text)
    var
        HtmlRendererPage: Page "HTML Renderer";
        HtmlContent: InStream;
        HtmlText: Text;
        LocalizedName: Text;
    begin
        LocalizedName := GetLocalizedResourceName(BaseResourceName);

        if (LocalizedName <> BaseResourceName) and TryGetResource(LocalizedName, HtmlContent) then
            HtmlContent.ReadText(HtmlText)
        else begin
            NavApp.GetResource(BaseResourceName, HtmlContent, TextEncoding::UTF8);
            HtmlContent.ReadText(HtmlText);
        end;

        HtmlRendererPage.Render(HtmlText);
        HtmlRendererPage.RunModal();
    end;

    /// <summary>
    /// Builds the localized resource name by inserting the current UI language tag
    /// before the file extension, e.g. 'user-guide.html' → 'user-guide.de-DE.html'.
    /// Returns the base name unchanged when no language tag can be determined or
    /// when the language is English.
    /// </summary>
    local procedure GetLocalizedResourceName(BaseResourceName: Text): Text
    var
        LanguageTag: Text;
        DotPos: Integer;
    begin
        LanguageTag := GetLanguageTag();
        if LanguageTag = '' then
            exit(BaseResourceName);

        DotPos := BaseResourceName.LastIndexOf('.');
        if DotPos <= 0 then
            exit(BaseResourceName);

        exit(BaseResourceName.Substring(1, DotPos - 1) + '.' + LanguageTag + BaseResourceName.Substring(DotPos));
    end;

    /// <summary>
    /// Returns a BCP-47 language tag (e.g. 'de-DE') for the current BC UI language,
    /// or an empty string for English or any unmapped language.
    /// Add further LCID mappings here as additional language variants are created.
    /// </summary>
    local procedure GetLanguageTag(): Text
    begin
        case GlobalLanguage() of
            1031, 3079, 2055, 5127: // de-DE, de-AT, de-CH, de-LI
                exit('de-DE');
            else
                exit('');
        end;
    end;

    /// <summary>
    /// Attempts to load a named resource. Returns false if the resource does not
    /// exist, allowing the caller to fall back gracefully without a runtime error.
    /// </summary>
    [TryFunction]
    local procedure TryGetResource(ResourceName: Text; var Content: InStream)
    begin
        NavApp.GetResource(ResourceName, Content, TextEncoding::UTF8);
    end;
}
