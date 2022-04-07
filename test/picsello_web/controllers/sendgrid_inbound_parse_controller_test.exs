defmodule PicselloWeb.SendgridInboundParseControllerTest do
  use PicselloWeb.ConnCase, async: true
  alias Picsello.{Repo, ClientMessage, Job}

  setup do
    Mox.stub_with(Picsello.MockBambooAdapter, Picsello.Sandbox.BambooAdapter)
    :ok
  end

  test "parses the response", %{conn: conn} do
    user = insert(:user)
    job = insert(:lead, user: user)
    token = Job.token(job)

    params = %{
      "SPF" => "pass",
      "attachments" => "0",
      "charsets" =>
        "{\"to\":\"UTF-8\",\"html\":\"UTF-8\",\"subject\":\"UTF-8\",\"from\":\"UTF-8\",\"text\":\"UTF-8\"}",
      "dkim" => "{@hashrocket-com.20210112.gappssmtp.com : pass}",
      "envelope" =>
        "{\"to\":[\"#{token}@dev-inbox.picsello.com\"],\"from\":\"gabriel@hashrocket.com\"}",
      "from" => "Gabriel Reis <gabriel@hashrocket.com>",
      "headers" =>
        "Received: by mx0100p1iad2.sendgrid.net with SMTP id KIWufUVVEq Fri, 29 Oct 2021 14:10:51 +0000 (UTC)\nReceived: from mail-oi1-f181.google.com (unknown [209.85.167.181]) by mx0100p1iad2.sendgrid.net (Postfix) with ESMTPS id A13F53E0BF9 for <SFMyNTY.g2gDYgAAA-duBgAhhFDMfAFiAAFRgA.3MvD-pk1M3D4nl9C3P_3CWyh0OQKVMBbgiPX71FRCgk@dev-inbox.picsello.com>; Fri, 29 Oct 2021 14:10:51 +0000 (UTC)\nReceived: by mail-oi1-f181.google.com with SMTP id n11so5363432oig.6 for <SFMyNTY.g2gDYgAAA-duBgAhhFDMfAFiAAFRgA.3MvD-pk1M3D4nl9C3P_3CWyh0OQKVMBbgiPX71FRCgk@dev-inbox.picsello.com>; Fri, 29 Oct 2021 07:10:51 -0700 (PDT)\nDKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed; d=hashrocket-com.20210112.gappssmtp.com; s=20210112; h=mime-version:references:in-reply-to:from:date:message-id:subject:to; bh=JKHPXFbt9wgOfDNwiAiFaJa8ChViwWQ5nid9FIjpcqc=; b=avBzUJlaLb8J1TLImuektXoNvQnTBo9Ax61l5vY/le/kh6U0o3vPKUPvnQ8paFcDbT jke4/V9GNvENzhYkSCd7p0NWWWQp9YIVXZcJMz3DSODsHZgXhZCjvr2OZQMb+F6pZkyU vJoM4TgvTJUcdU3MZa7cYAJX5XkElY39mQdHFjxnqqZglU0CUewy3AmUpdLb/SBzEvL8 5N2EJuwKvrHUu150jRTQ2DjZzfs+1k9Cr3p//T3ur7+ht+5kQkJaEuWl9q/UOEn2V5KH mnRjikGgfN2L5l5FMwBkFs7P/vl/J2ji8kMeB130zFSLnVoHpppSvuQJcMSeVYe/YPFR 9rlQ==\nX-Google-DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed; d=1e100.net; s=20210112; h=x-gm-message-state:mime-version:references:in-reply-to:from:date :message-id:subject:to; bh=JKHPXFbt9wgOfDNwiAiFaJa8ChViwWQ5nid9FIjpcqc=; b=3rXA0D4Tix9eLesn3gZcGeKebvqvEWOap1KEsS5ccAu+qXcgGc4u2vEQC8xAi3x7Qh FdW14tzGUJPBvY5kiiwniIpqtezTfNNcvBICghwSHhwqAKOspKjcAeIDS8qTuMoZ7OVH ULF03C9NLZy1XYXf+NyB3IOLTMw+jcmpiaRaBTM33xNq8dUn7IBA6o+EjR6udnxn/HLZ 7jBkx1z2+4qq2aJIOcHY0lterpw7x8M/N4P057QOYsM9zVg08FygjR2fLITqUrVX0NXJ yW6b/83KfEzAaCL3ly9iw77sRCMYRzxZw+usW1DF8umK+fijU/eRyNm2kmWEpRnwxagD iDxg==\nX-Gm-Message-State: AOAM5306ETZVtlslfO1aHTmuj3IsJqKJX9IMWA2gRrFch/oAtVT+idAn fEmtg5Vlxrunwxh3FmVpfr7/4FHKFbGL+9qlrQbRwg1dcjs=\nX-Google-Smtp-Source: ABdhPJw9syjIueiMvtDOJWV1G5XcvV1m0XgkijVntcfkoQRM0h6NvL5uOAJ69rz5n/VRSXwDSyjX4vWaRw3m9/wT/+w=\nX-Received: by 2002:aca:3903:: with SMTP id g3mr6166386oia.12.1635516650750; Fri, 29 Oct 2021 07:10:50 -0700 (PDT)\nMIME-Version: 1.0\nReferences: <rTTJL3kdSrG-ZE7TDcH3bg@geopod-ismtpd-3-2>\nIn-Reply-To: <rTTJL3kdSrG-ZE7TDcH3bg@geopod-ismtpd-3-2>\nFrom: Gabriel Reis <gabriel@hashrocket.com>\nDate: Fri, 29 Oct 2021 10:10:39 -0400\nMessage-ID: <CA+kSsF-FOWSH-Pq1feT95w5QM_4JPxb=KAzEWYMb2CsYe4_4zg@mail.gmail.com>\nSubject: Re: Test Subject\nTo: SFMyNTY.g2gDYgAAA-duBgAhhFDMfAFiAAFRgA.3MvD-pk1M3D4nl9C3P_3CWyh0OQKVMBbgiPX71FRCgk@dev-inbox.picsello.com\nContent-Type: multipart/alternative; boundary=\"000000000000fe16fd05cf7e64b1\"\n",
      "html" => """
      <div dir="ltr">This is my response</div><br><div class="gmail_quote"><div dir="ltr" class="gmail_attr">On Fri, Oct 29, 2021 at 9:50 AM &lt;<a href="mailto:noreply@picsello.com">noreply@picsello.com</a>&gt; wrote:<br></div><blockquote class="gmail_quote" style="margin:0px 0px 0px 0.8ex;border-left:1px solid rgb(204,204,204);padding-left:1ex"><u></u>
      <div>
      <center class="gmail-m_-8297536787681701837wrapper">
        <div>
          <table cellpadding="0" cellspacing="0" border="0" width="100%" class="gmail-m_-8297536787681701837wrapper" bgcolor="#FFFFFF">
            <tbody><tr>
              <td valign="top" bgcolor="#FFFFFF" width="100%">
                <table width="100%" role="content-container" align="center" cellpadding="0" cellspacing="0" border="0">
                  <tbody><tr>
                    <td width="100%">
                      <table width="100%" cellpadding="0" cellspacing="0" border="0">
                        <tbody><tr>
                          <td>

                                    <table width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:600px" align="center">
                                      <tbody><tr>

      <td role="modules-container" style="padding:0px;color:rgb(0,0,0);text-align:left" bgcolor="#FFFFFF" width="100%" align="left"><table class="gmail-m_-8297536787681701837preheader" role="module" border="0" cellpadding="0" cellspacing="0" width="100%" style="opacity:0;color:transparent;height:0px;width:0px;display:none">
      <tbody><tr>
      <td role="module-content">
        <p></p>
      </td>
      </tr>
      </tbody></table><table role="module" border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout:fixed">
      <tbody>
      <tr>
        <td height="100%" valign="top" role="module-content"><p>Test body</p></td>
      </tr>
      </tbody>
      </table><div role="module" style="color:rgb(68,68,68);font-size:12px;line-height:20px;padding:16px;text-align:center"><div></div><p style="font-size:12px;line-height:20px"><a>Unsubscribe</a> - <a>Unsubscribe Preferences</a></p></div></td>
                                      </tr>
                                    </tbody></table>


                          </td>
                        </tr>
                      </tbody></table>
                    </td>
                  </tr>
                </tbody></table>
              </td>
            </tr>
          </tbody></table>
        </div>
      </center>
      <img alt="" width="1" height="1" border="0" style="height: 1px; width: 1px; border-width: 0px; margin: 0px; padding: 0px;"></div>
      </blockquote></div>
      """,
      "sender_ip" => "209.85.167.181",
      "subject" => "Re: Test Subject",
      "text" =>
        "This is my response\r\n\r\nOn Fri, Oct 29, 2021 at 9:50 AM <noreply@picsello.com> wrote:\r\n\r\n> Test body\r\n>\r\n> Unsubscribe - Unsubscribe Preferences\r\n>\n",
      "to" => "Photography <#{token}@dev-inbox.picsello.com>"
    }

    reply_html = Map.get(params, "html")
    job_id = job.id

    conn |> post(Routes.sendgrid_inbound_parse_path(conn, :parse), params)

    assert [
             %{
               body_html: ^reply_html,
               body_text: "This is my response",
               outbound: false,
               job_id: ^job_id
             }
           ] = Repo.all(ClientMessage)

    assert_receive {:delivered_email, email}
    %{"subject" => subject, "body" => body} = email |> email_substitutions
    assert "You’ve got mail!" = subject
    assert body =~ "You have received a reply from Mary Jane!"
  end
end
