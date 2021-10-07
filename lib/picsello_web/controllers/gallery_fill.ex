defmodule PicselloWeb.GalleryFillController do
  @moduledoc """
    Test galleries builder
  """

  use PicselloWeb, :controller

  import Ecto.Query

  alias Picsello.Galleries

  def new(conn, %{"hash" => hash}) when hash in ["Avery"] do
    found = Galleries.get_gallery_by_hash(hash)

    if found == nil do
      build(hash)
    end

    redirect(conn, to: Routes.gallery_client_show_path(conn, :show, hash))
  end

  def new(conn, _) do
    redirect(conn, to: "/")
  end

  defp build("Avery") do
    job_id = get_job_id()

    {:ok, gallery} =
      Galleries.create_gallery(%{
        name: "Avery only",
        status: "draft",
        job_id: job_id,
        client_link_hash: "Avery"
      })

    data = [
      {1, "Avery-2-1.jpg",
       "https://ucf73dd1867128b284e3aa91da2d.previews.dropboxusercontent.com/p/thumb/ABTQkKxJcG8Yf3unmxRB9EJDMB9J3IVJXhhEzoJPhD4LedJYVhXGA6VvQz3LL6LiKdU11L1edDw42XJxZ4QfK2Wi-eRPGJG0TxjmNHh2g5W_HNFXXnZeEEcjCWRBmjZVAKiIpOYPS6GMCIUvBTzMbSpPncXvUeqUY56zgkoa-LaxCIK2RPB7gCiv2ckuzaS9elg0HMOFYG3yB4yn-s4HUj_4i6FmsrjZCOb1KBs6NNulhcbnK4jX74hgdzfwXXEzhvUIbKm-tvZaRYTDbvuuaLWxDG3owRGX5QON83qykIKh2fnoGmNwaLhaIJjln3o8bOtRttNWofQfEbLMxIQFp9UF9tb2xpwn4ZfdPgzCgBSmghJJyomUcuNBPSm2umJ6X3NRrwpfbz9-3rM8sj3px7acanWrO_MQqm8oaLYN-lgGEv69HEGdrc0OHFCZMRqot5ZJe7_92g-Aa0O2y9HvbBOjS8eE_Qk2gVwZHT_Eb-cpcA/p.jpeg?fv_content=true&size_mode=5"},
      {2, "Avery-2-2.jpg",
       "https://ucd9d6bb458fe5f9f228703a4d48.previews.dropboxusercontent.com/p/thumb/ABRq7OnTzqgcixAOCgqixZF65-i3kdx3wZe6ny_vhxVOfA4WIxZ7FOtIj1RYObof8OX6r_-HMcrBN8QttO32szAZso981iS8YKwLDwabPYSO0guy2wxiLOKqTsm2D33mFeadpN0t4-A0gQAD9s-a2Z-Atop7ph4nx33yXaxfdgmIEBplXqEyKo35ljScKn2hCmIUG1E9YuzcJcFGB28NOgau4Mb-UYkTx5grzW3Zlpj3gasJtVkDP8yqwjC9w0UBOY8dmNn7XZ3S-RsgnLnFOGCxS6MfKHylQzBTEITOlp1Jt1D1i9c6Xhr4yto6Oydr8iKo-uWwnC3k-IXjy6U1KiJsowBEJIsY93ZyYCsmbbvjRUZjyPF1LmdrJWY5BXU4COq8LDS3xPApUEGgSRLo6rLO-yCwrwI00UaFFuh3_zg7TbXY7zU1-Mr_7m2ryeYo0zlsnQcW54g3DMSbbfAf-mkNeRRNwOnfDBaSluXOUECOeA/p.jpeg?fv_content=true&size_mode=5"},
      {3, "Avery-2-3.jpg",
       "https://ucdf2761473464717a85674a3f7e.previews.dropboxusercontent.com/p/thumb/ABRc1e1yL40LCfVHJMHNx9P82c3ECJDM5P3HphU5f8S-ecrZP-M-I20p-woLQ-ZQQFrq2lM0w28_Xpj7qAH9FOWXGWAOfFVVQWMmerxJoAcJCLYzQRl_TNS8nV1lck4hJmPt12QaevkUsAB3xfrh1U9lW6hWR6Wh5-J72OaExho_qYLDfbPRyJnTWsBbQJzJoOX8RK8bHjHHOc360eexP2fJCZobB-PVoXYApvdXMlf4wTwr4AeeyOnBZ3ry0i-K_88UtuK1D-6mEgKhpAyNrzSNz0GkK8Lgke3Lv48M8gNYhrtYSZ_4pV22NdliE6J1rVrlqg_NlkFYRteDOskW3Y1Uo3JrlIjZrexdqUQK29_Wz29ikAgp60UZDTjT1OPRJrb-LWlT24ndXhVEHTxR6cVqVnRVtGhYjw8l34sbC8hpZA/p.jpeg?fv_content=true&size_mode=5"},
      {4, "Avery-2-4.jpg",
       "https://uc63939ee459ee4453418d66bc22.previews.dropboxusercontent.com/p/thumb/ABSegP1WqhJXgTbCsb0V57i6sswyBKeWNtFqyuPZDWovHbsz-IZ65CkOQFyTEU6VLp-KkwtwPAqyMXRe46zNmJ-gDrh_5wj9_Dtj09DpljN4DbN_g_rOPmTv-oFHLCEhiebnvHRpplvW5vzu5rvcT5MQgJ_GLXPs4GO_sy8vdF2YzXMhSXLC6whf6M0S9nJ08GLHWaHq0QOC8gbAViij1G7ATtSu3R4tpRB3orwrOiJE_GgwoWyedfyXbFd5LWb4b9H4Wh-G6DWfAqQthLMfKabWdvpwSs_rfIFSybPd1rrACvEItpIpe-nBX0BKPH3zR-C76YJemmFHKBwLk6yR0vitFzwpsgsF6ZRPu_8nMmWjNUp-xeixtXpWumU3zOIAGfAMlSAzBjKdOJC-bLiCZc_JpmbWCZ2deOVbqHleYa--h8zcQVvgA3S2w-m3B-lqD2TiRuphc_gutyzIrpv5kUDQp5_V3UuawuJ7C8eYI0HJUg/p.jpeg?fv_content=true&size_mode=5"},
      {5, "Avery-2-5.jpg",
       "https://uc4d534d7a7b99532dd390adddfa.previews.dropboxusercontent.com/p/thumb/ABQQDNQS2ECap0kCi8nNgE3JbP8bWv6D1n1cDllere1HRUhrlQadUFez0G0WL0Kgzb1x01SJt-_j7QEwD_PXS9AYGKnjTJk-gTW4ui6g_4hBSdstkWdimSHyK_WJSgeXap0AHjhPYBlCpquAfXEzJ5ieXIYNyJyEdAem54JtAG0BAiuOD2dvoW8dOOCmsK1HtCBAHKKeIm3kLCXE2jcY8UOSQ3hqLDMCDMbnmFTJzDX1igu9U5sP5rnKQ0K_0XKnaQKYZ_A-NHGSOvg9_7xpr0IRLZ1ncGD7KswdjeldVbJQ3wYPEDWwAAgLfKIwYJ4sNSnUapdOk0A-lklp3DaTC72Jx0wXaZkTMrCz6EexemOSdXu4lWG1N4fpPEffBRN63FhgjAa8GpLyiVky2yZu_QMyP0ZtG70JW-5ws0Vq4DzxKQ/p.jpeg?fv_content=true&size_mode=5"},
      {6, "Avery-2-6.jpg",
       "https://uce52d0386d81e043ec08e59c7ba.previews.dropboxusercontent.com/p/thumb/ABSzBIshhOa78bU0Da7z4mzTwHnJahPkneNL8T4timt_XvOmkv7Tke_KZnlUaoz8wKfUwriyW0ESrgH8OUS9tjHUTDnR0wB240lA_YJQ9zVBZrYp7uTpTZhgL4KOG7jpxxg42liTD7BDhRNXRI8olMtqoUvbkz08IKQlCfbp22q-NRG8OYFAXERpfid752z6hzMtYpx7dlf-DSsMBsclXSCF4bvbdDKk2qMwQAF0FWpGarXzYKpjYHPzC5PoCXDhoJcAgP--MyFVpY_m34ppNaywi0mCOqAy1lJH9fwTTQ8783z_06jJ57O0uNrM0rne-vzCoC8e444O8xO1ySyMuZu7cFErMEeDUsp4IXVUkgSDATD6gDemYTJI_hSXbssudik79pGJfSe92mYZHIKxQKQGN3o1dru7S4lSxYtNVjKmDg/p.jpeg?fv_content=true&size_mode=5"},
      {7, "Avery-2-7.jpg",
       "https://uc60b4fb6eb58e3df655d385fb84.previews.dropboxusercontent.com/p/thumb/ABRtTl5ICDY_uHL9ZlfUhvuMne6AG8cd2qL3mahGOxltQcBQskZmZLPRUujs0DJrJEU2hB-zVyM8GBPAvMS_FsT1KfSc00X2FOsn3AsDpQO-eJqmR_rNKjiGV6ptyk0XYrBLd2TjFfO_s0oHZe3t96KG20jZInkL25ytO0_QLjwQykoKS6tujDFxQ0Zb--sLJfKXQTtmIX3D2MVBiBCMIXzdH6XK6G8fAGVaWhCQft5Wl0snDwl-HbJnk0_rekWgztovyG06EACkbYKqIruP-vEfvJqs4vxeZdc0R7cMymWbxpVY9Lb1hNVVn7ZQfbuTM4ZT1XtwD8XlZgVu1IGqwcSWDvt5prPwKTiGvnYntNxE3_wHQ1eKJEilBtf28jq1wTMc0U529UY-jcpjgubJ-XKRfC69NJkM4zRiYTD91PIaFg/p.jpeg?fv_content=true&size_mode=5"},
      {8, "Avery-2-8.jpg",
       "https://uc0a175e037702a4336d1919cb2f.previews.dropboxusercontent.com/p/thumb/ABTvC9B4YzL-7RGXtjvGdM7NOYi8wSIMD0UbQAkh1Lfc5wxX8gB7L7BIivGk4ClYnObgVJ9DiF5A0d1ezATBpt1h4TKOlyDHdjfXcq5AlbkYQb6f8CY3A24oq_8nGZ45BeeLJp0XoAvEXpj7N0Yqts5zA-Qk50qfGr89Ay0gUWR4MrWaN7HgRl2Q01iREUuyu0rOZBqBEnfk082iDMSzNfYdjaByH60ArQgjn5XuajmUDFjYx8IBaRWo2-VfXVEGQeuSCnFZaG76LtN6-fspaYDWe7dt69KQug0OvCL0WPq4EXpDbMohYYYAE2KUP1m1lEVivyPVjq1rKOmSDtPAM02gML4hYY3GNarCJtayB9ZTWuYQzVnh59L1zLFYjq-8E6fBvT4BPJ8PRUVyeRFujuMIung-Ji-7h6n36elr_fKaZg/p.jpeg?fv_content=true&size_mode=5"},
      {9, "Avery-2-9.jpg",
       "https://uc8a26cbd8e37518b32c71132e80.previews.dropboxusercontent.com/p/thumb/ABRCATsvkyYO7Ct2YraLdFjLMChSpa9gqrjiFWMqT6jFZgs64GBSaOfNgpV3MpunD4viOB63ck6TMIJ3YBNldjeD9mnIlv5WayeZ50BOJluf1GnXxB15XDXfRxF41-7_5AoebExXZ4UJRb0VGJ7fZ3FnomW0ADnoJnpvEu-j_Ky5N9TCitGGZUbD7xHEOHoQ5Zvq-APZK20_ZrGcZs9zQgUDiDzPRHbfW35h8XCkXhLVEh70orA71njk1seSRKfQ-fMu4t8uehUVnuKplChOwFFuAMTctEG7pLZNoVr-txZHyKKrZ18sY3CX5r0uZ8i19v0a7iVzW8SN-V_akoJWSmDqN60-u6csVbsTxgarz29wNg/p.jpeg?fv_content=true&size_mode=5"},
      {10, "Avery-2-10.jpg",
       "https://uc511914eb3a8e318fbb582532d6.previews.dropboxusercontent.com/p/thumb/ABSEGCnz8U1yV0zsnndAhWN49SFMEfmGVPPpuQlWvmRbCwYKHOv3jW4DFSUt5OTkLXkTV35El2Ks8aWCq6zA6fGKTxltGilDK12Pm6ChYowhpEOJCZuTOgM1dyw1M6CeH_Bqed1cWl2LgS3QhKDkHCNwhQVoGp3xt9v6YaM-5_Ld2997_atKuFeF68j5mHBZhaIMmM1KxTo12ozemnx_zEB4Udd3-toAT7--O3okl5pS1u5TpFa5PsPQ0OAuIi52FJk0IF8L60LeAYier7M2GIvJi7wivVYwpKDV93BXbD2ux_5eTNg3NjhvEbY7AcDPpZiqQy3wz-QyhbSa4oHz2mTGbRd_2wZINZH-R3yLbeZx1buJhKmUnHWIbmeIToxeCtxnOR5UvAfW8kqRnzqGxvQsevLat0KqEnDene7qv0w3cwSjhCaw-LIVpJHZqLvmZPKpvkT5rI-MZyF64Gw8cEb_HhV_J9IXJNyKPFT4h3VHSA/p.jpeg?fv_content=true&size_mode=5"},
      {11, "Avery-2-11.jpg",
       "https://uc1f414af182d68d73f7bc677b34.previews.dropboxusercontent.com/p/thumb/ABQHD8Ds4TcZ0mMvASWTUPUlyMAfG835esJ5RK_rv6dVwxgV9nOTUP7SVnjQbvB-Dm9w_VteuXCirvy3yhvax-nIVKnbbWh91P9FAPHw2nJKPZDxlcnyjEwIpkKnk8nHhD4ryetFTJBZW7p0MJDPvJtRX41VyziBwpg77Ujk2mmOBUDu5dIsPDOvurThIoAdUKOUgvBi8PDfWv7UuHcEL_-qtiIWCCV4P5hjn77v70i63rXvUvJcFUPDJ5GM0gd1wqUGIq8-wd2Ne4aF60sSq3tTWLshBPabWx9U9CAEsuL-jFBQbKEyv9oCa3W3cclJNqlrn1BZ7gta2fWMBS4Y1-vPkzQQDPHhLhtRCqGLEN9FkZmCsp19zXwMGB8yneOtiLHDtlmIPv2BVwT4Roam1RNzRJ59NgqSYmEkUuc9MmI32XEiaUff-SuLdBsnMmpcJsvEaDi5OdM_Jidf2QwpAGSQ5NcaaHDD80nAgG7W1e41PA/p.jpeg?fv_content=true&size_mode=5"},
      {12, "Avery-2-12.jpg",
       "https://ucfbecc98560af20fa6bc440ff42.previews.dropboxusercontent.com/p/thumb/ABRTkblIqpdT-Wck89FAODl8hVDBLQsgy_SJ2Zp5tpOhMeO-c_uG88VfWb0gHmM2nusfAHm81PFxlKm48jUpSBR2aGX3FLx_RP_okDRQJwiIOj7Z4njVL8F4LDS0gJPa4I60DwLn0zOyU014Zz-Nsnyv3gmFyJLgKlk4fX53jaGNynLk6kumoUkb6fnCKNwdDmKmrKxXZIUrwDySzfId3qwBTmRZztamLsYZw0_vyPnxSiGZMkaSEG4Ctd1RJZmFT0ucjAygzWwTXeuMPxcSH6nUUgfME2ji6-GvtaVNYAIrv61BbPEIePUT1HZpjFlQRIjAeuyzjCGJ__AtJPtMgd5pWDEeBTcZOsdMqzXjpUFChIvLOBAVosZYTCuSiGYzDSO3z5wM3Gx6pLLRmJmrz0nj2bj4GDJ1VBwIdHKf2sVyGJZ5fyZ1PuARMVFml4aHtlVBI8rmRiTNqQWPa_kh_w_ZvRWd0Q-1SfXyK4qRoIOFFA/p.jpeg?fv_content=true&size_mode=5"},
      {13, "Avery-2-13.jpg",
       "https://uc445e1a90df937920a5a0a9968b.previews.dropboxusercontent.com/p/thumb/ABTh2a9jdnev7HPh1qp7L5B7Sg8PlFFr3sHOQZtAgoQwN0LJtGdW525ia3dZ8uGFAQfzPnO6a3z7HnFAIy8apN36Fb-hvP6rVObsL53Phok53Y8VguVEMB_sJQSXkWk5hrOwgeeQx5ptBGB18rA3rWsUTZ4Rq7uH1EqRe8P53-igdTey5joyc6sU3BK4Vf410GvaXB91tJMzcycJ0_dPusTaP0X0CD8KDVx2aD8EliIDacywVyLjssE6hfcK4JNCH2NPJBtncJIsO4E-_cv7LhD-7Wwuj4SLxIzqxv6__-X1Sa4cwUEPtEDKeFuTCB-u5EweCMsG8UUWiDTKSrQcl34cKSFjsuRefuUxbcl9HsGFvbgWP6054JGUHggsxX-2qNU1EN0atZGbHcAZh020SZRsKXuf3RYDq2cLzkkjwz4UTZKPFdkaeg9Hvc_DiG0ZvgrMXvvjUHNdjhkF-FjjhvXCiheu3jE9ZdYDRa0aU75IDg/p.jpeg?fv_content=true&size_mode=5"},
      {14, "Avery-2-14.jpg",
       "https://uc67c285d3935c93f2e093122ddd.previews.dropboxusercontent.com/p/thumb/ABRzDbC8FfPPIrOJau2qiL9IxxOHSvZD3dfmieQj3ysLyaW1dnCP_BRZkJG6LB53IipHdGgIaf7XYjG-jvu_NnqCXpzS1IKqHcm5PsDBPlfT4CxIDgTpnd7uWEeY6W9LDAO5Gcy5C9l__sscP_0z5CY6KSjY8Qi3RCqmSmctdg28L6TvDgUyhjNXXu2zma3Dqt0N5BzWXPv_-3Js7jlAhxMGTcQr6I1Br1ybZ8J6o5QAu7UggsqbldjpJ-kWR6WJTMYi8MATJsbikkQNHfDbFwFpx7-SnR2ZYzUvc0SyJiMugeytRjnMhAWeUvqRImktatqH0nO8T8sqDG_cnFucljBZvLOMO6EIShahLV1I6EHs2uYi5MSpd0xaJ6UyefJddimNDeViL2rv3Cu9mDJbZEio78tOqSIwDQBJsAnmvUYLcChhHndP4pOrRvd6pUK9Y1QQrxelAwY9wzL3mx_JHxHZf6GheFPvkuoFwwYv5gmsiQ/p.jpeg?fv_content=true&size_mode=5"},
      {15, "Avery-2-15.jpg",
       "https://uc4660e626120d57ce98cac9a292.previews.dropboxusercontent.com/p/thumb/ABTy0Qm99YdMkpRE4KelBzj_7padS3KKIVdWRvTZB94e6kwph8K906FAkiwQ8C1yzA6MLTxjomGrPvqDp2igwLgoMaj0F5GSBl-l9qkpvVyRdXxCWPsKqAGl-bhax8h3ogps7ntFksDWAxW_aITgspKuWbj5jNj4-hgpvsMiOpGIqH7rTbfvUtvpqu_NPd6n74UYD2DO8v7y95uXoT3RVlxWTrGmD6-jF4T9WGAmbv_zN_YqjmYRLc2K_2f4ODUUeKPxCqMwaxFY0Mf9Ya-HaFAU67iDUT3En2s6evTyDdQGEk11Vu5wJYYrlKLLu-7NiKU-7Dn5xRcuIS_oqkZiBN2teKALwR8t6OOtOn2hD4qN97ri75Lrs_mk24kDb4-uR_tVtBqOEjH_-IWEHhQ72rlWHM_Wdv6s1zTLhEGhzKHpLw/p.jpeg?fv_content=true&size_mode=5"},
      {16, "Avery-2-16.jpg",
       "https://ucac61329e6732d6f10d9ca5d9e9.previews.dropboxusercontent.com/p/thumb/ABRQITJte8LtsNDn7lC8BcoWPbrAAdTLmfczR2n_2zT5peGxhRrVoI4YlkfQNfMvkemiB3oYMPYtOJDn_z5HUxnxmtq1HEpnHxAUN1afEMkVg58XyVfS3zMV1o7nIYzUNb92IAUizsuBo8wKPeOJ6I4Kbn1xjm5w1pPiM19u-0L0ulMomhOusHnRvkXKUhgrdgAdSJyg9CmrjZD9UomIIRivVYRxcj9ZidR8B4ZxmNSKhxJUT54xQn6MtActGv2dOfJRn28XdFS0zU7u5PqHe1JUGIM1MVsx3ufFuw2h57cEy47afwCAjGSjyIdl04f6o3cXedIIiNKgxkWUlrDHAT9KfgALmFCibLU57H1KReU5hi_z1a7783nKWzhFyRjk_f85Grfnf-470zGJ8t74envclUwpKxMq8K41a-BcbJU8YtDv4l8DJjfqEGzUT-bPpgMb9vgcEhBI5KOQxCwMsCEF8aDIds1cRpL8t0nJVBOfJA/p.jpeg?fv_content=true&size_mode=5"},
      {17, "Avery-2-17.jpg",
       "https://uc96011475825a5c7cd2a4ad83ac.previews.dropboxusercontent.com/p/thumb/ABSHis904yBrkds_M9D26IU_4XiHwSdiSZ01vFOkSY12NHW10-BHVkY1itJCxGAjlbRYuqrlp9nbEjqtcce7f6l2sHG2iw7ST33IpM0YUb3OYt-iQEXB6FmaOaSzsXwwqmNsf7rqe4BeSm1ZlwF1fXCbsCDNfZzCpkNrISrsTGbKBzF7jfZWA-vdUmvzn-3eIu9WQnwIYuvxXiLK8sg6O3IKZj-UZ9eQLY0IpA3BseBGgU81IAkT-wBItVoOo-dpTcO1wLS8to9KlynPg0sr0Ws5JmW6gU49ql-Gf0Gz5n89Mj2mHjfzr8PPT75c7uGHVQ3TGVIvBZKOYFP7q4LKGDRdrPHWwKV3Nqr-BTvTmxvG0qsKfPkJx7Kfwf6Mmjsi44_HnOUWz30QzuTJL0jKrkQd27b2qVftgebGu7XNnlh7Ew/p.jpeg?fv_content=true&size_mode=5"},
      {18, "Avery-2-18.jpg",
       "https://uc0d9e8ea0cc0a8e8d8aee6fdfe6.previews.dropboxusercontent.com/p/thumb/ABRbaNmfr90dyMCyZmUq8Vo-i6pKId3MEMXh8J9iW3YRHfb5Z5k_VoIyApgUomxRksMOLypqiVqyYNM7Mv6aC7XyCsyQIk61xUB-JvU-FsgzYXhLdQ-ZANJtU5dmKkUqZWNAdTFCuEpXOjHbisc8qa1rRa2M_-t9kn2JjYIMCpRNNv4KDWrMitmSjowRVIp7YpHWrx84zSKSr920pNZ40BGNYzi31AxGz87u1JPwszLNU5z_QfQDV41c5V5wJWuxOukbHKCcP13Gg0k9HgbMFzuK2EDcGJ1HN_znlAvDCIANXrnwUZzo7RCsiFX-p9m80BPtxVy5jutV70p5eqvFc-YlgbHNQ60zzEzUbTqmzFBGBPBRrsg-VxLxJtisLDxyLB7STrJN8QnPp_92zdy_Cpgj_0kaOjYvuQz89daReZlzOg/p.jpeg?fv_content=true&size_mode=5"}
    ]

    photos =
      data
      |> Enum.map(fn {position, name, url} ->
        {:ok, photo} =
          Galleries.create_photo(%{
            gallery_id: gallery.id,
            name: name,
            original_url: url,
            client_copy_url: url,
            preview_url: url,
            position: position + 0.0
          })

        photo
      end)

    [cover | _] = photos

    Galleries.update_gallery(gallery, %{cover_photo_id: cover.id})
  end

  defp build(_), do: :ok

  defp find_or_create(model, create_function) do
    some =
      model
      |> limit(1)
      |> Picsello.Repo.one()

    if some do
      some.id
    else
      {:ok, new} = create_function.()

      new.id
    end
  end

  defp get_job_id() do
    find_or_create(Picsello.Job, fn ->
      client_id = get_client_id()

      %{client_id: client_id, type: "wedding"}
      |> Picsello.Job.create_changeset()
      |> Picsello.Repo.insert()
    end)
  end

  defp get_client_id() do
    find_or_create(Picsello.Client, fn ->
      organization_id = get_organization_id()

      %{
        organization_id: organization_id,
        name: "Test Client",
        email: "test@example.net",
        phone: "+5555555555"
      }
      |> Picsello.Client.create_changeset()
      |> Picsello.Repo.insert()
    end)
  end

  defp get_organization_id() do
    find_or_create(Picsello.Organization, fn ->
      %{name: "Test organization"}
      |> Picsello.Organization.registration_changeset()
      |> Picsello.Repo.insert()
    end)
  end
end
