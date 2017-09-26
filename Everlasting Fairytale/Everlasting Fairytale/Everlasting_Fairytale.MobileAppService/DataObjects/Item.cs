using Microsoft.Azure.Mobile.Server;

namespace Everlasting_Fairytale.MobileAppService.DataObjects
{
    public class Item : EntityData
    {
        public string Text { get; set; }
        public string Description { get; set; }
    }
}