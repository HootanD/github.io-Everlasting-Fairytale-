﻿using System;
using System.Collections.Generic;
using System.Threading.Tasks;

using Everlasting_Fairytale.Services;

using Microsoft.WindowsAzure.MobileServices;
using Xamarin.Forms;

[assembly: Dependency(typeof(Everlasting_Fairytale.Droid.Authentication.SocialAuthenticator))]
namespace Everlasting_Fairytale.Droid.Authentication
{
    public class SocialAuthenticator : BaseSocialAuthenticator
    {
        public override async Task<MobileServiceUser> LoginAsync(IMobileServiceClient client, MobileServiceAuthenticationProvider provider, IDictionary<string, string> parameters = null)
        {
            try
            {

                return await client.LoginAsync(Forms.Context, provider, parameters);

            }
            catch (Exception e)
            {
                e.Data["method"] = "LoginAsync";
            }

            return null;
        }

        public override void ClearCookies()
        {
            try
            {
                if ((int)global::Android.OS.Build.VERSION.SdkInt >= 21)
                    global::Android.Webkit.CookieManager.Instance.RemoveAllCookies(null);
            }
            catch (Exception ex)
            {
            }
        }
    }
}