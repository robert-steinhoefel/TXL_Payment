namespace P3.TXL.Payment.Documentation;
using System.Integration;

page 51103 "HTML Renderer"
{
    Caption = 'HTML Renderer';
    ApplicationArea = All;
    PageType = Card;
    layout
    {
        area(Content)
        {
            usercontrol(html; WebPageViewer)
            {
                ApplicationArea = All;
                trigger ControlAddInReady(CallbackUrl: Text)
                begin
                    CurrPage.html.SetContent(InputHTML);
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin

    end;

    var
        InputHTML: Text;

    procedure Render(HTML: Text)
    begin
        InputHTML := HTML;
    end;
}
