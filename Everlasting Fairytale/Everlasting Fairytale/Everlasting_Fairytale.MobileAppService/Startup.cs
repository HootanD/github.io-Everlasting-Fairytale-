using Microsoft.Owin;
using Owin;

[assembly: OwinStartup(typeof(Everlasting_Fairytale.MobileAppService.Startup))]

namespace Everlasting_Fairytale.MobileAppService
{
    public partial class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            ConfigureMobileApp(app);
        }
    }
}