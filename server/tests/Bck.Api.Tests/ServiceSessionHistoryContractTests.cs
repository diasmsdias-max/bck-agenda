using Bck.Api.Features.ServiceSessions;
using Xunit;

namespace Bck.Api.Tests;

public sealed class ServiceSessionHistoryContractTests
{
    [Fact] public void History_entry_preserves_actor_action_payload_and_time(){var id=Guid.NewGuid();var actor=Guid.NewGuid();var changedAt=new DateTimeOffset(2026,9,13,12,30,0,TimeSpan.Zero);var entry=new ServiceSessionHistorySummary(id,"ITEM_ADDED",actor,"{\"total\":100}","{\"total\":150}",changedAt);Assert.Equal(id,entry.Id);Assert.Equal("ITEM_ADDED",entry.Action);Assert.Equal(actor,entry.ChangedByUserId);Assert.Equal("{\"total\":100}",entry.BeforeJson);Assert.Equal("{\"total\":150}",entry.AfterJson);Assert.Equal(changedAt,entry.ChangedAt);}
    [Theory][InlineData("OPENED")][InlineData("ITEM_ADDED")][InlineData("NOTES_UPDATED")][InlineData("FINISHED")] public void Operational_actions_are_valid_preserved_history_events(string action){var entry=new ServiceSessionHistorySummary(Guid.NewGuid(),action,Guid.NewGuid(),null,null,DateTimeOffset.UtcNow);Assert.Equal(action,entry.Action);}
}
