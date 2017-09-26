﻿using System.Threading.Tasks;
using System.Windows.Input;

using Everlasting_Fairytale.Models;
using Everlasting_Fairytale.Helpers;
using Everlasting_Fairytale.Services;

using Xamarin.Forms;

namespace Everlasting_Fairytale.ViewModels
{
	public class LoginViewModel : BaseViewModel
	{
		public LoginViewModel()
		{
			SignInCommand = new Command(async () => await SignIn());
			NotNowCommand = new Command(App.GoToMainPage);
		}

		string message = string.Empty;
		public string Message
		{
			get { return message; }
			set { message = value; OnPropertyChanged(); }
		}

		public ICommand NotNowCommand { get; }
		public ICommand SignInCommand { get; }

		async Task SignIn()
		{
			try
			{
				IsBusy = true;
				Message = "Signing In...";

				// Log the user in
				await TryLoginAsync();
			}
			finally
			{
				Message = string.Empty;
				IsBusy = false;

				if (Settings.IsLoggedIn)
					App.GoToMainPage();
			}
		}

		public static async Task<bool> TryLoginAsync()
		{
			var authentication = DependencyService.Get<IAuthenticator>();
			authentication.ClearCookies();

			var dataStore = DependencyService.Get<IDataStore<Item>>() as AzureDataStore;
			await dataStore.InitializeAsync();

            if (dataStore.UseAuthentication)
            {
                var user = await authentication.LoginAsync(dataStore.MobileService, dataStore.AuthProvider, App.LoginParameters);
                if (user == null)
                {
                    MessagingCenter.Send(new MessagingCenterAlert
                    {
                        Title = "Sign In Error",
                        Message = "Unable to sign in, please check your credentials and try again.",
                        Cancel = "OK"
                    }, "message");
                    return false;
                }

                Settings.AuthToken = user?.MobileServiceAuthenticationToken ?? string.Empty;
                Settings.UserId = user?.UserId ?? string.Empty;
            }

			return true;
		}
	}
}