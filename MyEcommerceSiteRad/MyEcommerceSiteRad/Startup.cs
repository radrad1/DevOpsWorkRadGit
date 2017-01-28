using Microsoft.Owin;
using Owin;

[assembly: OwinStartupAttribute(typeof(MyEcommerceSiteRad.Startup))]
namespace MyEcommerceSiteRad
{
    public partial class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            ConfigureAuth(app);
        }
    }
}
